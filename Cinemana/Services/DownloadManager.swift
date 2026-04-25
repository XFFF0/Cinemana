import Foundation
import Combine

final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published var downloads: [DownloadItem] = []
    @Published var downloadedVideos: [DownloadedVideo] = []
    @Published var downloadedSubtitles: [DownloadedSubtitle] = []

    private let fileManager = FileManager.default
    private let downloadsDirectory: URL
    private let subtitlesDirectory: URL

    private lazy var backgroundSession: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.cinemana.background.downloads")
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    private var taskMetadata: [Int: DownloadTaskMetadata] = [:]

    private override init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        downloadsDirectory = documentsPath.appendingPathComponent("Downloads", isDirectory: true)
        subtitlesDirectory = documentsPath.appendingPathComponent("Subtitles", isDirectory: true)

        super.init()

        try? fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: subtitlesDirectory, withIntermediateDirectories: true)

        loadDownloadedVideos()
        loadDownloadedSubtitles()
    }

    func downloadVideo(_ video: VideoModel, quality: String = "720") {
        Task {
            do {
                let files = try await APIService.shared.getTranscodedFiles(videoId: video.nb)
                guard let selectedFile = files.first(where: { $0.resolution == quality }) ?? files.first,
                      let videoUrlString = selectedFile.videoUrl,
                      let videoUrl = URL(string: videoUrlString) else {
                    return
                }

                let destinationUrl = downloadsDirectory.appendingPathComponent("\(video.nb)_\(quality).mp4")
                startDownload(
                    sourceURL: videoUrl,
                    destinationURL: destinationUrl,
                    item: DownloadItem(
                        videoId: "\(video.nb)_\(quality)",
                        title: video.title,
                        thumbnailUrl: video.thumbnailUrl,
                        quality: quality,
                        progress: 0,
                        status: .downloading,
                        kind: .video
                    ),
                    metadata: .video(
                        videoId: video.nb,
                        title: video.title,
                        thumbnailUrl: video.thumbnailUrl,
                        quality: quality,
                        destinationURL: destinationUrl
                    )
                )
            } catch {
                print("Download preparation error: \(error)")
            }
        }
    }

    func downloadSubtitle(video: VideoModel, subtitleURL: URL, languageCode: String) {
        let safeLanguage = languageCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "ar" : languageCode
        let fileExtension = subtitleURL.pathExtension.isEmpty ? "srt" : subtitleURL.pathExtension
        let destinationURL = subtitlesDirectory.appendingPathComponent("\(video.nb)_\(safeLanguage).\(fileExtension)")

        startDownload(
            sourceURL: subtitleURL,
            destinationURL: destinationURL,
            item: DownloadItem(
                videoId: "sub_\(video.nb)_\(safeLanguage)",
                title: "\(video.title) • Subtitle",
                thumbnailUrl: video.thumbnailUrl,
                quality: safeLanguage.uppercased(),
                progress: 0,
                status: .downloading,
                kind: .subtitle
            ),
            metadata: .subtitle(
                videoId: video.nb,
                title: video.title,
                languageCode: safeLanguage,
                destinationURL: destinationURL
            )
        )
    }

    func cancelDownload(videoId: String) {
        if let taskIdentifier = taskMetadata.first(where: { $0.value.itemId == videoId })?.key {
            backgroundSession.getAllTasks { [weak self] tasks in
                guard let self else { return }
                tasks.first(where: { $0.taskIdentifier == taskIdentifier })?.cancel()
            }
        }

        Task { @MainActor in
            self.downloads.removeAll { $0.videoId == videoId }
        }
    }

    func deleteDownload(_ video: DownloadedVideo) {
        try? fileManager.removeItem(atPath: video.localPath)
        downloadedVideos.removeAll { $0.videoId == video.videoId && $0.quality == video.quality }
        saveDownloadedVideos()
    }

    func deleteSubtitle(_ subtitle: DownloadedSubtitle) {
        try? fileManager.removeItem(atPath: subtitle.localPath)
        downloadedSubtitles.removeAll { $0.id == subtitle.id }
        saveDownloadedSubtitles()
    }

    func getLocalVideoUrl(_ video: DownloadedVideo) -> URL? {
        let url = URL(fileURLWithPath: video.localPath)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    private func startDownload(sourceURL: URL, destinationURL: URL, item: DownloadItem, metadata: DownloadTaskMetadata) {
        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }

        var request = URLRequest(url: sourceURL)
        request.timeoutInterval = 120

        let task = backgroundSession.downloadTask(with: request)
        taskMetadata[task.taskIdentifier] = metadata.withItemId(item.videoId)

        Task { @MainActor in
            self.downloads.append(item)
        }

        task.resume()
    }

    private func loadDownloadedVideos() {
        if let data = UserDefaults.standard.data(forKey: "downloadedVideos"),
           let videos = try? JSONDecoder().decode([DownloadedVideo].self, from: data) {
            downloadedVideos = videos.filter { fileManager.fileExists(atPath: $0.localPath) }
        }
    }

    private func saveDownloadedVideos() {
        if let data = try? JSONEncoder().encode(downloadedVideos) {
            UserDefaults.standard.set(data, forKey: "downloadedVideos")
        }
    }

    private func loadDownloadedSubtitles() {
        if let data = UserDefaults.standard.data(forKey: "downloadedSubtitles"),
           let subtitles = try? JSONDecoder().decode([DownloadedSubtitle].self, from: data) {
            downloadedSubtitles = subtitles.filter { fileManager.fileExists(atPath: $0.localPath) }
        }
    }

    private func saveDownloadedSubtitles() {
        if let data = try? JSONEncoder().encode(downloadedSubtitles) {
            UserDefaults.standard.set(data, forKey: "downloadedSubtitles")
        }
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0,
              let metadata = taskMetadata[downloadTask.taskIdentifier] else {
            return
        }

        let progress = (Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)) * 100
        Task { @MainActor in
            if let index = self.downloads.firstIndex(where: { $0.videoId == metadata.itemId }) {
                self.downloads[index].progress = progress
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let metadata = taskMetadata[downloadTask.taskIdentifier] else { return }

        do {
            if fileManager.fileExists(atPath: metadata.destinationURL.path) {
                try fileManager.removeItem(at: metadata.destinationURL)
            }

            try fileManager.moveItem(at: location, to: metadata.destinationURL)

            Task { @MainActor in
                if let index = self.downloads.firstIndex(where: { $0.videoId == metadata.itemId }) {
                    self.downloads[index].status = .completed
                    self.downloads[index].progress = 100
                }

                switch metadata.payload {
                case .video(let videoId, let title, let thumbnailUrl, let quality):
                    self.downloadedVideos.append(
                        DownloadedVideo(
                            videoId: videoId,
                            title: title,
                            thumbnailUrl: thumbnailUrl,
                            quality: quality,
                            localPath: metadata.destinationURL.path,
                            downloadedAt: Date()
                        )
                    )
                    self.saveDownloadedVideos()

                case .subtitle(let videoId, let title, let languageCode):
                    self.downloadedSubtitles.append(
                        DownloadedSubtitle(
                            videoId: videoId,
                            title: title,
                            languageCode: languageCode,
                            localPath: metadata.destinationURL.path,
                            downloadedAt: Date()
                        )
                    )
                    self.saveDownloadedSubtitles()
                }
            }
        } catch {
            Task { @MainActor in
                if let index = self.downloads.firstIndex(where: { $0.videoId == metadata.itemId }) {
                    self.downloads[index].status = .failed
                }
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let metadata = taskMetadata[task.taskIdentifier] else { return }

        defer { taskMetadata[task.taskIdentifier] = nil }

        guard error != nil else { return }

        Task { @MainActor in
            if let index = self.downloads.firstIndex(where: { $0.videoId == metadata.itemId }) {
                self.downloads[index].status = .failed
            }
        }
    }
}

struct DownloadItem: Identifiable {
    let id = UUID()
    let videoId: String
    let title: String
    let thumbnailUrl: String?
    let quality: String
    var progress: Double
    var status: DownloadStatus
    let kind: DownloadKind

    enum DownloadStatus {
        case downloading
        case paused
        case completed
        case failed
    }

    enum DownloadKind {
        case video
        case subtitle
    }
}

struct DownloadedVideo: Codable, Identifiable {
    var id: String { "\(videoId)_\(quality)" }
    let videoId: String
    let title: String
    let thumbnailUrl: String?
    let quality: String
    let localPath: String
    let downloadedAt: Date
}

struct DownloadedSubtitle: Codable, Identifiable {
    var id: String { "\(videoId)_\(languageCode)_\(localPath)" }
    let videoId: String
    let title: String
    let languageCode: String
    let localPath: String
    let downloadedAt: Date
}

private struct DownloadTaskMetadata {
    enum Payload {
        case video(videoId: String, title: String, thumbnailUrl: String?, quality: String)
        case subtitle(videoId: String, title: String, languageCode: String)
    }

    var itemId: String
    let destinationURL: URL
    let payload: Payload

    static func video(videoId: String, title: String, thumbnailUrl: String?, quality: String, destinationURL: URL) -> DownloadTaskMetadata {
        DownloadTaskMetadata(
            itemId: "",
            destinationURL: destinationURL,
            payload: .video(videoId: videoId, title: title, thumbnailUrl: thumbnailUrl, quality: quality)
        )
    }

    static func subtitle(videoId: String, title: String, languageCode: String, destinationURL: URL) -> DownloadTaskMetadata {
        DownloadTaskMetadata(
            itemId: "",
            destinationURL: destinationURL,
            payload: .subtitle(videoId: videoId, title: title, languageCode: languageCode)
        )
    }

    func withItemId(_ itemId: String) -> DownloadTaskMetadata {
        var copy = self
        copy.itemId = itemId
        return copy
    }
}

import Foundation
import Combine

class DownloadManager: ObservableObject {
    static let shared = DownloadManager()
    
    @Published var downloads: [DownloadItem] = []
    @Published var downloadedVideos: [DownloadedVideo] = []
    
    private let fileManager = FileManager.default
    private let downloadsDirectory: URL
    
    private init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        downloadsDirectory = documentsPath.appendingPathComponent("Downloads")
        
        try? fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        loadDownloadedVideos()
    }
    
    func downloadVideo(_ video: VideoModel, quality: String = "720") {
        Task {
            do {
                let files = try await APIService.shared.getTranscodedFiles(videoId: video.nb)
                
                guard let selectedFile = files.first(where: { $0.resolution == quality }) ?? files.first else {
                    return
                }
                
                guard let videoUrlString = selectedFile.videoUrl,
                      let videoUrl = URL(string: videoUrlString) else {
                    return
                }
                
                let downloadItem = DownloadItem(
                    videoId: video.nb,
                    title: video.title,
                    thumbnailUrl: video.thumbnailUrl,
                    quality: quality,
                    progress: 0,
                    status: .downloading
                )
                
                await MainActor.run {
                    self.downloads.append(downloadItem)
                }
                
                let destinationUrl = downloadsDirectory.appendingPathComponent("\(video.nb)_\(quality).mp4")
                
                let (tempUrl, response) = try await URLSession.shared.download(from: videoUrl)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    await MainActor.run {
                        if let index = self.downloads.firstIndex(where: { $0.videoId == video.nb }) {
                            self.downloads[index].status = .failed
                        }
                    }
                    return
                }
                
                if fileManager.fileExists(atPath: destinationUrl.path) {
                    try fileManager.removeItem(at: destinationUrl)
                }
                
                try fileManager.moveItem(at: tempUrl, to: destinationUrl)
                
                let downloadedVideo = DownloadedVideo(
                    videoId: video.nb,
                    title: video.title,
                    thumbnailUrl: video.thumbnailUrl,
                    quality: quality,
                    localPath: destinationUrl.path,
                    downloadedAt: Date()
                )
                
                await MainActor.run {
                    self.downloadedVideos.append(downloadedVideo)
                    self.saveDownloadedVideos()
                    if let index = self.downloads.firstIndex(where: { $0.videoId == video.nb }) {
                        self.downloads[index].status = .completed
                        self.downloads[index].progress = 100
                    }
                }
            } catch {
                print("Download error: \(error)")
                await MainActor.run {
                    if let index = self.downloads.firstIndex(where: { $0.videoId == video.nb }) {
                        self.downloads[index].status = .failed
                    }
                }
            }
        }
    }
    
    func cancelDownload(videoId: String) {
        downloads.removeAll { $0.videoId == videoId }
    }
    
    func deleteDownload(_ video: DownloadedVideo) {
        try? fileManager.removeItem(atPath: video.localPath)
        downloadedVideos.removeAll { $0.videoId == video.videoId }
        saveDownloadedVideos()
    }
    
    func getLocalVideoUrl(_ video: DownloadedVideo) -> URL? {
        let url = URL(fileURLWithPath: video.localPath)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }
    
    private func loadDownloadedVideos() {
        if let data = UserDefaults.standard.data(forKey: "downloadedVideos"),
           let videos = try? JSONDecoder().decode([DownloadedVideo].self, from: data) {
            downloadedVideos = videos.filter { FileManager.default.fileExists(atPath: $0.localPath) }
        }
    }
    
    private func saveDownloadedVideos() {
        if let data = try? JSONEncoder().encode(downloadedVideos) {
            UserDefaults.standard.set(data, forKey: "downloadedVideos")
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
    
    enum DownloadStatus {
        case downloading
        case paused
        case completed
        case failed
    }
}

struct DownloadedVideo: Codable, Identifiable {
    var id: String { videoId }
    let videoId: String
    let title: String
    let thumbnailUrl: String?
    let quality: String
    let localPath: String
    let downloadedAt: Date
}
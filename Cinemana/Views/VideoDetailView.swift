import SwiftUI
import AVKit
import Kingfisher

struct VideoDetailView: View {
    let video: VideoModel
    @StateObject private var viewModel = VideoDetailViewModel()
    @State private var showPlayer = false
    @State private var selectedQuality: String = "720"
    @State private var showSubtitleSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                posterSection
                infoSection
                actionsSection
                categoriesSection
                castSection
            }
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(colors: [Color.black, Color(red: 0.08, green: 0.09, blue: 0.14)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .fullScreenCover(isPresented: $showPlayer) {
            VideoPlayerView(video: video, quality: selectedQuality)
        }
        .sheet(isPresented: $showSubtitleSheet) {
            SubtitleDownloadSheet(video: video)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            viewModel.checkFavorite(video)
        }
    }

    private var posterSection: some View {
        ZStack(alignment: .bottomLeading) {
            KFImage(URL(string: video.posterUrl ?? ""))
                .resizable()
                .aspectRatio(16/9, contentMode: .fill)
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.black.opacity(0.35))
                }

            VStack(alignment: .leading, spacing: 10) {
                Text(video.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    metaPill(text: video.year ?? "-")
                    metaPill(text: video.duration ?? "--")
                    metaPill(text: "⭐️ \(video.rate ?? "--")")
                }
            }
            .padding(16)

            Button(action: { showPlayer = true }) {
                Image(systemName: "play.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(.red)
                    .clipShape(Circle())
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .padding(.horizontal)
    }

    private var infoSection: some View {
        Group {
            if let content = video.arContent ?? video.enContent {
                Text(content)
                    .foregroundColor(.white.opacity(0.86))
                    .padding(14)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                actionButton(title: "مشاهدة", icon: "play.fill", color: .red) {
                    showPlayer = true
                }

                actionButton(title: "تحميل فيديو", icon: "arrow.down.circle.fill", color: .blue) {
                    viewModel.downloadVideo(video, quality: selectedQuality)
                }
            }

            HStack(spacing: 10) {
                actionButton(title: "تحميل الترجمة من الإنترنت", icon: "captions.bubble.fill", color: .teal) {
                    showSubtitleSheet = true
                }

                Button(action: { viewModel.toggleFavorite(video) }) {
                    Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundColor(viewModel.isFavorite ? .red : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.horizontal)
    }

    private var categoriesSection: some View {
        Group {
            if let categories = video.categories, !categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.nb) { category in
                            Text(category.name ?? category.nameEn ?? "")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private var castSection: some View {
        Group {
            if let actors = video.actorsInfo, !actors.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("الممثلين")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(actors, id: \.nb) { actor in
                                VStack(spacing: 8) {
                                    KFImage(URL(string: actor.picture ?? ""))
                                        .resizable()
                                        .frame(width: 68, height: 68)
                                        .clipShape(Circle())

                                    Text(actor.name ?? "")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                }
                                .frame(width: 82)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    private func metaPill(text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.2))
            .clipShape(Capsule())
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(color.opacity(0.88))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

final class VideoDetailViewModel: ObservableObject {
    @Published var isFavorite = false

    private let downloadManager = DownloadManager.shared

    func downloadVideo(_ video: VideoModel, quality: String) {
        downloadManager.downloadVideo(video, quality: quality)
    }

    func downloadSubtitle(video: VideoModel, subtitleURLString: String, languageCode: String) throws {
        guard let url = URL(string: subtitleURLString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw SubtitleError.invalidURL
        }

        downloadManager.downloadSubtitle(video: video, subtitleURL: url, languageCode: languageCode)
    }

    func toggleFavorite(_ video: VideoModel) {
        Task {
            do {
                if isFavorite {
                    try await APIService.shared.removeSubscription(videoId: video.nb)
                } else {
                    try await APIService.shared.addSubscription(videoId: video.nb)
                }
                await MainActor.run {
                    isFavorite.toggle()
                }
            } catch {
                print("Favorite error: \(error)")
            }
        }
    }

    func checkFavorite(_ video: VideoModel) {
        Task {
            do {
                let subscriptions = try await APIService.shared.getSubscriptions()
                await MainActor.run {
                    isFavorite = subscriptions.contains { $0.nb == video.nb }
                }
            } catch {
                print("Check favorite error: \(error)")
            }
        }
    }

    enum SubtitleError: LocalizedError {
        case invalidURL

        var errorDescription: String? {
            "رابط الترجمة غير صحيح"
        }
    }
}

struct SubtitleDownloadSheet: View {
    let video: VideoModel
    @StateObject private var viewModel = VideoDetailViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var subtitleURL = ""
    @State private var languageCode = "ar"
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("رابط ملف الترجمة") {
                    TextField("https://example.com/subtitle.srt", text: $subtitleURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("اللغة (ar / en)", text: $languageCode)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("تحميل الترجمة")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("بدء التحميل") {
                        do {
                            try viewModel.downloadSubtitle(video: video, subtitleURLString: subtitleURL, languageCode: languageCode)
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .disabled(subtitleURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct VideoPlayerView: View {
    let video: VideoModel
    let quality: String
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }

            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            }

            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding()

                Spacer()
            }
        }
        .onAppear {
            loadVideo()
        }
        .onDisappear {
            player?.pause()
        }
    }

    private func loadVideo() {
        Task {
            do {
                let files = try await APIService.shared.getTranscodedFiles(videoId: video.nb)

                guard let selectedFile = files.first(where: { $0.resolution == quality }) ?? files.first,
                      let urlString = selectedFile.videoUrl,
                      let url = URL(string: urlString) else {
                    await MainActor.run { isLoading = false }
                    return
                }

                let playerItem = AVPlayerItem(url: url)
                await MainActor.run {
                    self.player = AVPlayer(playerItem: playerItem)
                    self.isLoading = false
                    self.player?.play()
                }

                try await APIService.shared.addToHistory(videoId: video.nb, kind: video.kind ?? "movie")
            } catch {
                await MainActor.run { isLoading = false }
                print("Player error: \(error)")
            }
        }
    }
}

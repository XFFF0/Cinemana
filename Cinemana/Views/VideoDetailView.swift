import SwiftUI
import AVKit
import Kingfisher

struct VideoDetailView: View {
    let video: VideoModel
    @StateObject private var viewModel = VideoDetailViewModel()
    @State private var showPlayer = false
    @State private var selectedQuality: String = "720"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    KFImage(URL(string: video.posterUrl ?? ""))
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(height: 250)
                        .clipped()
                    
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: 250)
                    
                    Button(action: { showPlayer = true }) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(video.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 16) {
                        if let year = video.year {
                            Label(year, systemImage: "calendar")
                        }
                        if let duration = video.duration {
                            Label(duration, systemImage: "clock")
                        }
                        if let rate = video.rate {
                            Label(rate, systemImage: "star.fill")
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    
                    if let content = video.arContent ?? video.enContent {
                        Text(content)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(4)
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: { showPlayer = true }) {
                            Label("Watch", systemImage: "play.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        Button(action: { viewModel.downloadVideo(video, quality: selectedQuality) }) {
                            Label("Download", systemImage: "arrow.down.circle")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        Button(action: { viewModel.toggleFavorite(video) }) {
                            Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundColor(viewModel.isFavorite ? .red : .white)
                                .padding()
                        }
                    }
                    .padding(.top, 8)
                    
                    if let categories = video.categories, !categories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(categories, id: \.nb) { category in
                                    Text(category.name ?? category.nameEn ?? "")
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.gray.opacity(0.3))
                                        .cornerRadius(15)
                                }
                            }
                        }
                    }
                    
                    if let actors = video.actorsInfo, !actors.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cast")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(actors, id: \.nb) { actor in
                                        VStack {
                                            KFImage(URL(string: actor.picture ?? ""))
                                                .resizable()
                                                .frame(width: 70, height: 70)
                                                .clipShape(Circle())
                                            Text(actor.name ?? "")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                        }
                                        .frame(width: 80)
                                    }
                                }
                            }
                        }
                        .padding(.top)
                    }
                }
                .padding()
            }
        }
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .fullScreenCover(isPresented: $showPlayer) {
            VideoPlayerView(video: video, quality: selectedQuality)
        }
        .onAppear {
            viewModel.checkFavorite(video)
        }
    }
}

class VideoDetailViewModel: ObservableObject {
    @Published var isFavorite = false
    @Published var transcodedFiles: [TranscodeFile] = []
    @Published var isLoading = false
    
    private let downloadManager = DownloadManager.shared
    
    func downloadVideo(_ video: VideoModel, quality: String) {
        downloadManager.downloadVideo(video, quality: quality)
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

#Preview {
    NavigationStack {
        VideoDetailView(video: VideoModel(
            nb: "1",
            arTitle: "Film Name",
            enTitle: "Film Name",
            kind: "movie",
            year: "2024",
            duration: "120 min",
            rate: "8.5"
        ))
    }
    .preferredColorScheme(.dark)
}
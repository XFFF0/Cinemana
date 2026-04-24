import SwiftUI
import AVKit
import Kingfisher

struct DownloadsView: View {
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var selectedVideo: DownloadedVideo?
    
    var body: some View {
        NavigationStack {
            Group {
                if downloadManager.downloadedVideos.isEmpty && downloadManager.downloads.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No downloads yet")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Downloaded movies and series will appear here")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if !downloadManager.downloads.isEmpty {
                            Section("Downloading") {
                                ForEach(downloadManager.downloads) { item in
                                    DownloadingRow(item: item) {
                                        downloadManager.cancelDownload(videoId: item.videoId)
                                    }
                                }
                            }
                            .listRowBackground(Color.black)
                        }
                        
                        if !downloadManager.downloadedVideos.isEmpty {
                            Section("Downloaded") {
                                ForEach(downloadManager.downloadedVideos) { video in
                                    DownloadedRow(video: video)
                                        .listRowBackground(Color.black)
                                        .onTapGesture {
                                            selectedVideo = video
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                downloadManager.deleteDownload(video)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                            .listRowBackground(Color.black)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.black)
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .fullScreenCover(item: $selectedVideo) { video in
                LocalPlayerView(video: video)
            }
        }
    }
}

struct DownloadingRow: View {
    let item: DownloadItem
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            KFImage(URL(string: item.thumbnailUrl ?? ""))
                .resizable()
                .aspectRatio(2/3, contentMode: .fill)
                .frame(width: 60, height: 90)
                .cornerRadius(6)
                .clipped()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(item.quality)p")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                ProgressView(value: item.progress / 100)
                    .tint(.red)
            }
            
            Spacer()
            
            if item.status == .downloading {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            } else if item.status == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if item.status == .failed {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DownloadedRow: View {
    let video: DownloadedVideo
    
    var body: some View {
        HStack(spacing: 12) {
            KFImage(URL(string: video.thumbnailUrl ?? ""))
                .resizable()
                .aspectRatio(2/3, contentMode: .fill)
                .frame(width: 60, height: 90)
                .cornerRadius(6)
                .clipped()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                HStack {
                    Text("\(video.quality)p")
                    Text("•")
                    Text(video.downloadedAt.formatted(date: .abbreviated, time: .omitted))
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundColor(.red)
        }
        .padding(.vertical, 4)
    }
}

struct LocalPlayerView: View {
    let video: DownloadedVideo
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
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
            if let url = DownloadManager.shared.getLocalVideoUrl(video) {
                player = AVPlayer(url: url)
                player?.play()
            }
        }
        .onDisappear {
            player?.pause()
        }
    }
}

extension DownloadedVideo: Identifiable {}

#Preview {
    DownloadsView()
        .preferredColorScheme(.dark)
}
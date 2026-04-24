import SwiftUI
import Kingfisher

struct HomeView: View {
    @EnvironmentObject var homeViewModel: HomeViewModel
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if homeViewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = homeViewModel.errorMessage {
                    VStack {
                        Text("Error loading content")
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.gray)
                        Button("Retry") {
                            Task {
                                await homeViewModel.refresh()
                            }
                        }
                    }
                } else {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if !homeViewModel.banners.isEmpty {
                            BannerCarousel(banners: homeViewModel.banners)
                        }
                        
                        if !homeViewModel.newlyVideos.isEmpty {
                            VideoSection(title: "الأحدث", videos: homeViewModel.newlyVideos)
                        }
                        
                        ForEach(homeViewModel.homeGroups) { group in
                            if let videos = group.videos, !videos.isEmpty {
                                VideoSection(
                                    title: group.groupName ?? group.groupNameEn ?? "",
                                    videos: videos
                                )
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .background(Color.black)
            .navigationTitle("Cinemana")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .refreshable {
                await homeViewModel.refresh()
            }
        }
    }
}

struct BannerCarousel: View {
    let banners: [VideoModel]
    @State private var currentIndex = 0
    
    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(banners.enumerated()), id: \.element.nb) { index, video in
                NavigationLink(destination: VideoDetailView(video: video)) {
                    KFImage(URL(string: video.posterUrl ?? ""))
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(height: 220)
                        .clipped()
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 220)
    }
}

struct VideoSection: View {
    let title: String
    let videos: [VideoModel]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(videos) { video in
                        NavigationLink(destination: VideoDetailView(video: video)) {
                            VideoCard(video: video)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct VideoCard: View {
    let video: VideoModel
    
    var body: some View {
        VStack(alignment: .leading) {
            KFImage(URL(string: video.thumbnailUrl ?? ""))
                .resizable()
                .aspectRatio(2/3, contentMode: .fill)
                .frame(width: 120, height: 180)
                .cornerRadius(8)
                .clipped()
            
            Text(video.title)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(width: 120, alignment: .leading)
        }
    }
}

struct LargeVideoCard: View {
    let video: VideoModel
    
    var body: some View {
        NavigationLink(destination: VideoDetailView(video: video)) {
            VStack(alignment: .leading) {
                KFImage(URL(string: video.posterUrl ?? ""))
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(height: 180)
                    .cornerRadius(10)
                    .clipped()
                
                Text(video.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(HomeViewModel())
        .preferredColorScheme(.dark)
}
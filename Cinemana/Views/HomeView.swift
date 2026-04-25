import SwiftUI
import Kingfisher

struct HomeView: View {
    @EnvironmentObject var homeViewModel: HomeViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if homeViewModel.isLoading {
                        HomeLoadingSkeleton()
                            .padding(.top, 4)
                    } else if let error = homeViewModel.errorMessage {
                        errorView(error)
                    } else {
                        if !homeViewModel.banners.isEmpty {
                            ModernBannerCarousel(banners: homeViewModel.banners)
                        }

                        if !homeViewModel.newlyVideos.isEmpty {
                            ModernVideoSection(title: "الأحدث", videos: homeViewModel.newlyVideos)
                        }

                        ForEach(homeViewModel.homeGroups) { group in
                            if let videos = group.videos, !videos.isEmpty {
                                ModernVideoSection(title: group.groupName ?? group.groupNameEn ?? "", videos: videos)
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .background(
                LinearGradient(colors: [Color.black, Color(red: 0.06, green: 0.07, blue: 0.14)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .navigationTitle("Cinemana")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .refreshable {
                await homeViewModel.refresh()
            }
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36))
                .foregroundColor(.white)
            Text("تعذر تحميل المحتوى")
                .foregroundColor(.white)
                .font(.headline)
            Text(error)
                .foregroundColor(.gray)
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("إعادة المحاولة") {
                Task { await homeViewModel.refresh() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

struct ModernBannerCarousel: View {
    let banners: [VideoModel]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(banners.prefix(5), id: \.nb) { video in
                    NavigationLink(destination: VideoDetailView(video: video)) {
                        ZStack(alignment: .bottomLeading) {
                            KFImage(URL(string: video.posterUrl ?? ""))
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                                .frame(width: 320, height: 190)
                                .clipShape(RoundedRectangle(cornerRadius: 18))

                            LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                                .clipShape(RoundedRectangle(cornerRadius: 18))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(video.title)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(video.year ?? "")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(12)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct ModernVideoSection: View {
    let title: String
    let videos: [VideoModel]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(videos) { video in
                        NavigationLink(destination: VideoDetailView(video: video)) {
                            ModernVideoCard(video: video)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct ModernVideoCard: View {
    let video: VideoModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            KFImage(URL(string: video.thumbnailUrl ?? ""))
                .resizable()
                .aspectRatio(2/3, contentMode: .fill)
                .frame(width: 132, height: 188)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .topTrailing) {
                    if let rate = video.rate {
                        Text("⭐️ \(rate)")
                            .font(.caption2)
                            .padding(6)
                            .background(.black.opacity(0.65))
                            .clipShape(Capsule())
                            .padding(6)
                    }
                }

            Text(video.title)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(width: 132, alignment: .leading)
        }
    }
}

struct HomeLoadingSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.11))
                .frame(height: 190)
                .padding(.horizontal)

            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 10) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.11))
                        .frame(width: 120, height: 18)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<5, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.11))
                                    .frame(width: 132, height: 188)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .redacted(reason: .placeholder)
    }
}

#Preview {
    HomeView()
        .environmentObject(HomeViewModel())
        .preferredColorScheme(.dark)
}

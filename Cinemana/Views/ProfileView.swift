import SwiftUI
import Kingfisher

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var history: [VideoModel] = []
    @State private var subscriptions: [VideoModel] = []
    @State private var selectedTab = 0
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        if let userInfo = authManager.userInfo {
                            if let pictureUrl = userInfo.pictureLarge ?? userInfo.pictureSmall,
                               let url = URL(string: pictureUrl) {
                                KFImage(url)
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(userInfo.name)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(userInfo.email)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("Guest")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.black)
                
                Section("Downloads") {
                    HStack {
                        Label("Downloaded", systemImage: "arrow.down.circle")
                        Spacer()
                        Text("\(downloadManager.downloadedVideos.count)")
                            .foregroundColor(.gray)
                    }
                    .foregroundColor(.white)
                    
                    HStack {
                        Label("Watching", systemImage: "arrow.down.circle.fill")
                        Spacer()
                        Text("\(downloadManager.downloads.count)")
                            .foregroundColor(.gray)
                    }
                    .foregroundColor(.white)
                }
                .listRowBackground(Color.black)
                
                Section("Menu") {
                    NavigationLink(destination: HistoryView()) {
                        Label("Watch History", systemImage: "clock")
                    }
                    
                    NavigationLink(destination: SubscriptionsView()) {
                        Label("My List", systemImage: "heart")
                    }
                    
                    NavigationLink(destination: SettingsView()) {
                        Label("Settings", systemImage: "gear")
                    }
                }
                .listRowBackground(Color.black)
                
                Section {
                    Button(action: logout) {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
                .listRowBackground(Color.black)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    private func logout() {
        authManager.logout()
    }
}

struct HistoryView: View {
    @State private var history: [VideoModel] = []
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if history.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No watch history")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(history) { video in
                        NavigationLink(destination: VideoDetailView(video: video)) {
                            HStack {
                                KFImage(URL(string: video.thumbnailUrl ?? ""))
                                    .resizable()
                                    .frame(width: 50, height: 75)
                                    .cornerRadius(4)
                                
                                VStack(alignment: .leading) {
                                    Text(video.title)
                                        .foregroundColor(.white)
                                    if let year = video.year {
                                        Text(year)
                                            .font(.caption)
                                            .foregroundColor(.gray)
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
        .navigationTitle("History")
        .task {
            await loadHistory()
        }
    }
    
    private func loadHistory() async {
        do {
            history = try await APIService.shared.getHistory()
        } catch {
            print("Error: \(error)")
        }
        isLoading = false
    }
}

struct SubscriptionsView: View {
    @State private var subscriptions: [VideoModel] = []
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if subscriptions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "heart")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No items in your list")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(subscriptions) { video in
                        NavigationLink(destination: VideoDetailView(video: video)) {
                            HStack {
                                KFImage(URL(string: video.thumbnailUrl ?? ""))
                                    .resizable()
                                    .frame(width: 50, height: 75)
                                    .cornerRadius(4)
                                
                                VStack(alignment: .leading) {
                                    Text(video.title)
                                        .foregroundColor(.white)
                                    if let kind = video.kind {
                                        Text(kind)
                                            .font(.caption)
                                            .foregroundColor(.gray)
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
        .navigationTitle("My List")
        .task {
            await loadSubscriptions()
        }
    }
    
    private func loadSubscriptions() async {
        do {
            subscriptions = try await APIService.shared.getSubscriptions()
        } catch {
            print("Error: \(error)")
        }
        isLoading = false
    }
}

struct SettingsView: View {
    @AppStorage("quality") private var quality = "720"
    @AppStorage("autoplay") private var autoplay = true
    @AppStorage("downloadWifiOnly") private var downloadWifiOnly = true
    
    var body: some View {
        List {
            Section("Playback") {
                Picker("Quality", selection: $quality) {
                    Text("480p").tag("480")
                    Text("720p").tag("720")
                    Text("1080p").tag("1080")
                }
                .foregroundColor(.white)
                
                Toggle("Autoplay next", isOn: $autoplay)
                    .tint(.red)
                    .foregroundColor(.white)
            }
            .listRowBackground(Color.black)
            
            Section("Downloads") {
                Toggle("Download on Wi-Fi only", isOn: $downloadWifiOnly)
                    .tint(.red)
                    .foregroundColor(.white)
            }
            .listRowBackground(Color.black)
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.gray)
                }
                .foregroundColor(.white)
            }
            .listRowBackground(Color.black)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Settings")
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager.shared)
        .preferredColorScheme(.dark)
}
import Foundation
import Combine

class HomeViewModel: ObservableObject {
    @Published var homeGroups: [VideosGroup] = []
    @Published var banners: [VideoModel] = []
    @Published var newlyVideos: [VideoModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    
    init() {
        Task {
            await loadHomeData()
        }
    }
    
    @MainActor
    func loadHomeData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let groups = apiService.getHomeGroups()
            async let banners = apiService.getBanners()
            async let newly = apiService.getNewlyVideos()
            
            let (fetchedGroups, fetchedBanners, fetchedNewly) = try await (groups, banners, newly)
            
            self.homeGroups = fetchedGroups
            self.banners = fetchedBanners
            self.newlyVideos = fetchedNewly
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func refresh() async {
        await loadHomeData()
    }
}
import Foundation

class APIService {
    static let shared = APIService()
    
    private let baseURL = "https://cinemana.shabakaty.cc/api/android/"
    private let identityBaseURL = "https://account.shabakaty.cc/"
    private let cdnBaseURL = "https://cnth2.shabakaty.cc/"
    
    private init() {}
    
    private func makeRequest<T: Decodable>(endpoint: String, method: String = "GET", body: Data? = nil, requiresAuth: Bool = false) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        
        if requiresAuth {
            let token = AuthManager.shared.accessToken
            if !token.isEmpty {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - Home & Content
    
    func getHomeGroups(language: String = "ar", parentalLevel: Int = 0) async throws -> [VideosGroup] {
        let response: HomeGroupsResponse = try await makeRequest(
            endpoint: "videoGroups/lang/\(language)/level/\(parentalLevel)"
        )
        return response.groups ?? []
    }
    
    func getNewlyVideos(parentalLevel: Int = 0, offset: Int = 12) async throws -> [VideoModel] {
        try await makeRequest(endpoint: "newlyVideosItems/level/\(parentalLevel)/offset/\(offset)/")
    }
    
    func getBanners(parentalLevel: Int = 0) async throws -> [VideoModel] {
        try await makeRequest(endpoint: "banner/level/\(parentalLevel)")
    }
    
    func getVideoDetails(videoId: String) async throws -> VideoModel {
        try await makeRequest(endpoint: "allVideoInfo/id/\(videoId)")
    }
    
    func getTranscodedFiles(videoId: String) async throws -> [TranscodeFile] {
        try await makeRequest(endpoint: "transcoddedFiles/id/\(videoId)")
    }
    
    func getSeriesEpisodes(rootEpisodeId: String) async throws -> [VideoModel] {
        try await makeRequest(endpoint: "videoSeason/id/\(rootEpisodeId)")
    }
    
    // MARK: - Search & Categories
    
    func searchVideos(
        query: String? = nil,
        type: String? = nil,
        year: String? = nil,
        categoryId: String? = nil,
        page: Int = 1,
        parentalLevel: Int = 0
    ) async throws -> [VideoModel] {
        var params: [String] = []
        if let query = query { params.append("videoTitle=\(query)") }
        if let type = type { params.append("type=\(type)") }
        if let year = year { params.append("year=\(year)") }
        if let categoryId = categoryId { params.append("category_id=\(categoryId)") }
        params.append("page=\(page)")
        params.append("level=\(parentalLevel)")
        
        let queryString = params.joined(separator: "&")
        return try await makeRequest(endpoint: "AdvancedSearch?\(queryString)")
    }
    
    func getCategories() async throws -> [NewCategoryItem] {
        try await makeRequest(endpoint: "categories")
    }
    
    func getCollections(parentalLevel: Int = 0) async throws -> [CollectionItem] {
        try await makeRequest(endpoint: "collectionsId/level/\(parentalLevel)")
    }
    
    func getCollectionDetails(collectionId: String, parentalLevel: Int = 0) async throws -> [CollectionItem] {
        try await makeRequest(endpoint: "getCollection/collectionID/\(collectionId)/level/\(parentalLevel)")
    }
    
    // MARK: - Video Pagination
    
    func getVideoListPagination(groupId: String, parentalLevel: Int = 0, itemsPerPage: Int = 20, page: Int = 1) async throws -> [VideoModel] {
        try await makeRequest(
            endpoint: "videoListPagination?groupID=\(groupId)&level=\(parentalLevel)&itemsPerPage=\(itemsPerPage)&page=\(page)"
        )
    }
    
    // MARK: - User Actions
    
    func addToHistory(videoId: String, kind: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: [
            "userId": AuthManager.shared.userInfo?.sub ?? "",
            "videoId": videoId,
            "kind": kind
        ])
        let _: EmptyResponse = try await makeRequest(endpoint: "addToHistory/", method: "POST", body: body, requiresAuth: true)
    }
    
    func getHistory(pageNumber: Int = 1, kind: String = "all") async throws -> [VideoModel] {
        let body = try JSONSerialization.data(withJSONObject: [
            "pageNumber": pageNumber,
            "userId": AuthManager.shared.userInfo?.sub ?? "",
            "kind": kind
        ])
        return try await makeRequest(endpoint: "history/", method: "POST", body: body, requiresAuth: true)
    }
    
    func addLike(videoId: String, likeValue: Int) async throws {
        let body = try JSONSerialization.data(withJSONObject: [
            "userId": AuthManager.shared.userInfo?.sub ?? "",
            "videoId": videoId,
            "likeValue": likeValue
        ])
        let _: EmptyResponse = try await makeRequest(endpoint: "addLike/", method: "POST", body: body, requiresAuth: true)
    }
    
    func getSubscriptions() async throws -> [VideoModel] {
        try await makeRequest(endpoint: "get_subscriptions", requiresAuth: true)
    }
    
    func addSubscription(videoId: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: [
            "userId": AuthManager.shared.userInfo?.sub ?? "",
            "video_id": videoId
        ])
        let _: EmptyResponse = try await makeRequest(endpoint: "add_subscriptions/", method: "POST", body: body, requiresAuth: true)
    }
    
    func removeSubscription(videoId: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: [
            "userId": AuthManager.shared.userInfo?.sub ?? "",
            "video_id": videoId
        ])
        let _: EmptyResponse = try await makeRequest(endpoint: "remove_subscriptions/", method: "POST", body: body, requiresAuth: true)
    }
}

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError
}

struct EmptyResponse: Codable {}
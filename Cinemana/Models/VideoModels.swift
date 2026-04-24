import Foundation

struct VideoModel: Codable, Identifiable, Hashable {
    var id: String { nb }
    let nb: String
    let arTitle: String?
    let enTitle: String?
    let customArTitle: String?
    let customEnTitle: String?
    let arContent: String?
    let enContent: String?
    let kind: String?
    let year: String?
    let duration: String?
    let stars: String?
    let rate: String?
    let filmRating: String?
    let seriesRating: String?
    let imgObjUrl: String?
    let imgMediumThumbObjUrl: String?
    let imgThumbObjUrl: String?
    let trailer: String?
    let imdbUrlRef: String?
    let episodeFlag: String?
    let episodeNummer: String?
    let season: String?
    let rootSeries: String?
    let listId: String?
    let itemDate: String?
    let publishDate: String?
    let videoLikesNumber: String?
    let videoDisLikesNumber: String?
    let videoViewsNumber: String?
    let videoCommentsNumber: Int?
    let showComments: Bool?
    let castable: String?
    let isSpecial: String?
    let hasIntroSkipping: Bool?
    let introSkipping: [String]?
    let skippingDurations: [String: String]?
    let translations: [String]?
    let categories: [Category]?
    let actorsInfo: [StaffInfo]?
    let directorsInfo: [StaffInfo]?
    let writersInfo: [StaffInfo]?
    let videoLanguages: [String: String]?
    
    var title: String {
        customArTitle ?? customEnTitle ?? arTitle ?? enTitle ?? ""
    }
    
    var thumbnailUrl: String? {
        imgMediumThumbObjUrl ?? imgThumbObjUrl ?? imgObjUrl
    }
    
    var posterUrl: String? {
        imgObjUrl
    }
    
    var isMovie: Bool {
        kind?.lowercased() == "movie"
    }
    
    var isSeries: Bool {
        kind?.lowercased() == "series"
    }
}

struct Category: Codable, Hashable {
    let nb: String?
    let name: String?
    let nameEn: String?
}

struct StaffInfo: Codable, Hashable {
    let nb: String?
    let name: String?
    let picture: String?
    let role: String?
}

struct TranscodeFile: Codable, Identifiable {
    var id: String { name ?? UUID().uuidString }
    let name: String?
    let resolution: String?
    let container: String?
    let transcoddedFileName: String?
    let videoUrl: String?
}

struct VideosGroup: Codable, Identifiable {
    var id: String { listId ?? UUID().uuidString }
    let listId: String?
    let groupName: String?
    let groupNameEn: String?
    let videos: [VideoModel]?
}

struct HomeGroupsResponse: Codable {
    let groups: [VideosGroup]?
}

struct CollectionItem: Codable, Identifiable {
    var id: String { nb ?? UUID().uuidString }
    let nb: String?
    let name: String?
    let nameEn: String?
    let imageUrl: String?
    let descriptionText: String?
    let descriptionEn: String?
    let videos: [VideoModel]?
}

struct NewCategoryItem: Codable, Identifiable {
    var id: String { nb ?? UUID().uuidString }
    let nb: String?
    let name: String?
    let nameEn: String?
    let imageUrl: String?
}

struct Comment: Codable, Identifiable {
    var id: String { nb ?? UUID().uuidString }
    let nb: String?
    let userId: String?
    let username: String?
    let userPicture: String?
    let comment: String?
    let commentDate: String?
    let likes: Int?
    let dislikes: Int?
    let userRate: String?
}

struct UserHistory: Codable, Identifiable {
    var id: String { videoId ?? UUID().uuidString }
    let videoId: String?
    let arTitle: String?
    let enTitle: String?
    let thumbnail: String?
    let watchedDuration: Int?
    let totalDuration: Int?
    let lastWatched: String?
    let kind: String?
}
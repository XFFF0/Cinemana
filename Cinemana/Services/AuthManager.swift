import Foundation

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isLoggedIn: Bool = false
    @Published var userInfo: UserInfo?
    @Published var accessToken: String = ""
    @Published var refreshToken: String = ""
    
    private let clientId = "cTnj9bUcDmr08B586K7pGFHy"
    private let clientSecret = "secret"
    
    private init() {
        loadTokens()
    }
    
    private func loadTokens() {
        if let token = UserDefaults.standard.string(forKey: "accessToken"), !token.isEmpty {
            accessToken = token
            refreshToken = UserDefaults.standard.string(forKey: "refreshToken") ?? ""
            isLoggedIn = true
            fetchUserInfo()
        }
    }
    
    func login(email: String, password: String) async throws {
        let base64Credentials = Data("\(clientId):\(clientSecret)".utf8).base64EncodedString()
        
        var request = URLRequest(url: URL(string: "https://account.shabakaty.cc/core/connect/token")!)
        request.httpMethod = "POST"
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "username": email,
            "password": password,
            "scope": "openid email offline_access earthlink.profile fileservice songster",
            "grant_type": "password"
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AuthError.loginFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        await MainActor.run {
            self.accessToken = tokenResponse.accessToken
            self.refreshToken = tokenResponse.refreshToken
            self.isLoggedIn = true
            
            UserDefaults.standard.set(tokenResponse.accessToken, forKey: "accessToken")
            UserDefaults.standard.set(tokenResponse.refreshToken, forKey: "refreshToken")
        }
        
        try await fetchUserInfo()
    }
    
    func fetchUserInfo() async throws {
        guard !accessToken.isEmpty else { return }
        
        var request = URLRequest(url: URL(string: "https://account.shabakaty.cc/core/connect/userinfo")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let userInfo = try? JSONDecoder().decode(UserInfo.self, from: data) {
            await MainActor.run {
                self.userInfo = userInfo
            }
        }
    }
    
    func refreshAccessToken() async throws {
        let base64Credentials = Data("\(clientId):\(clientSecret)".utf8).base64EncodedString()
        
        var request = URLRequest(url: URL(string: "https://account.shabakaty.cc/core/connect/token")!)
        request.httpMethod = "POST"
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "refresh_token": refreshToken,
            "scope": "openid email offline_access earthlink.profile fileservice songster",
            "grant_type": "refresh_token"
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AuthError.refreshFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        await MainActor.run {
            self.accessToken = tokenResponse.accessToken
            self.refreshToken = tokenResponse.refreshToken
            
            UserDefaults.standard.set(tokenResponse.accessToken, forKey: "accessToken")
            UserDefaults.standard.set(tokenResponse.refreshToken, forKey: "refreshToken")
        }
    }
    
    func logout() {
        accessToken = ""
        refreshToken = ""
        userInfo = nil
        isLoggedIn = false
        
        UserDefaults.standard.removeObject(forKey: "accessToken")
        UserDefaults.standard.removeObject(forKey: "refreshToken")
    }
}

enum AuthError: Error {
    case loginFailed
    case refreshFailed
    case invalidCredentials
}
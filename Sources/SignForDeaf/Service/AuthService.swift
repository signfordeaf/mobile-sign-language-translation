import Foundation

enum APIKeyError: Error {
    case invalidKey
}

class AuthService {
    
    // Singleton instance
    static let shared = AuthService()

    // Private apiKey variable
    private var apiKey: String = ""
    private var requestUrl: String = ""

    // Private init to prevent outside initialization
    private init() { }

    // Set the API key
    public func setApiKey(apiKey: String) {
        self.apiKey = apiKey
    }
    
    public func setRequestUrl(requestUrl: String) {
        self.requestUrl = requestUrl
    }

    // Get the API key
    public func getApiKey() -> String {
        return apiKey
    }
    
    public func getRequestUrl() -> String {
        return requestUrl
    }
}

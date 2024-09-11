import Foundation

enum APIError: Error {
    case invalidURL
    case requestFailed
    case invalidResponse
    case noData
    case decodingError
    case cancelled
}

class URLApiService {
    
    static let shared = URLApiService()
    private var dataTask: URLSessionDataTask?
    
    private let baseURL = AuthService.shared.getRequestUrl()
    private let rk = AuthService.shared.getApiKey()
    private let fdid = "16"
    private let tid = "23"
    private let language = "1"
    
    private init() {}
    
    func getSignVideo(s: String, completion: @escaping (Result<SignModel, APIError>) -> Void) {
        // URL ve parametreler
        let parameters = [
            "s": s,
            "rk": rk,
            "fdid": fdid,
            "tid": tid,
            "language": language
        ]
        
        guard var urlComponents = URLComponents(string: "\(baseURL)/Translate") else {
            completion(.failure(.invalidURL))
            return
        }
        
        urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = urlComponents.url else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        func sendRequest() {
             dataTask = URLSession.shared.dataTask(with: request) { data, response, error in
                if let _ = error {
                    if (error?.localizedDescription == "cancelled") {
                        completion(.failure(.cancelled))
                        return
                    } else {
                        completion(.failure(.requestFailed))
                        return
                    }
                    
                }
                
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.noData))
                    return
                }
                
                do {
                    let signModel = try SignModel(data: data)
                    if signModel.state == false {
                        // Eğer state false ise isteği tekrar yap
                        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                            sendRequest()
                        }
                    } else {
                        // Eğer state true ise başarıyla tamamla
                        completion(.success(signModel))
                    }
                } catch {
                    completion(.failure(.invalidResponse))
                }
            }
            
            dataTask?.resume()
        }
        
        // İlk isteği başlat
        sendRequest()
    }
    
    func cancelRequest() {
        print("İstek iptal edildi.")
        dataTask?.cancel()
    }
}

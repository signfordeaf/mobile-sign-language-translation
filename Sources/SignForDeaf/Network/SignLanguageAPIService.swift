// Network/SignLanguageAPIService.swift

import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case requestFailed
    case invalidResponse
    case noData
    case decodingError
    case cancelled
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .requestFailed: return "Request failed"
        case .invalidResponse: return "Invalid response"
        case .noData: return "No data received"
        case .decodingError: return "Failed to decode response"
        case .cancelled: return "Request cancelled"
        case .timeout: return "Request timed out"
        }
    }
}

/// URLSession client that polls the `/Translate` endpoint until a sign language
/// video is ready. Ported from the RN library's `SignLanguageAPIService`.
final class SignLanguageAPIService {

    private let config: SignForDeafConfig
    private var currentTask: URLSessionDataTask?
    private let maxRetries: Int = 30
    private let retryDelay: TimeInterval = 1.0

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration)
    }()

    init(config: SignForDeafConfig) {
        self.config = config
    }

    func getSignVideo(text: String, completion: @escaping (Result<SignModel, APIError>) -> Void) {
        guard var urlComponents = URLComponents(string: "\(config.apiUrl)/Translate") else {
            completion(.failure(.invalidURL))
            return
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "s", value: text),
            URLQueryItem(name: "url", value: config.originUrl),
            URLQueryItem(name: "rk", value: config.apiKey),
            URLQueryItem(name: "fdid", value: config.fdid),
            URLQueryItem(name: "tid", value: config.tid),
            URLQueryItem(name: "language", value: config.language.apiCode),
        ]

        guard let url = urlComponents.url else {
            completion(.failure(.invalidURL))
            return
        }

        sendRequestWithRetry(url: url, retryCount: 0, completion: completion)
    }

    private func sendRequestWithRetry(
        url: URL,
        retryCount: Int,
        completion: @escaping (Result<SignModel, APIError>) -> Void
    ) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(config.originUrl, forHTTPHeaderField: "Origin")

        currentTask = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            // Cancelled?
            if let nsError = error as NSError?, nsError.code == NSURLErrorCancelled {
                completion(.failure(.cancelled))
                return
            }

            if error != nil {
                completion(.failure(.requestFailed))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(.invalidResponse))
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            do {
                let signModel = try JSONDecoder().decode(SignModel.self, from: data)

                // Translation ready?
                if signModel.state == true {
                    completion(.success(signModel))
                } else if retryCount < self.maxRetries {
                    // Not ready yet — retry the same request after a short delay.
                    DispatchQueue.global().asyncAfter(deadline: .now() + self.retryDelay) { [weak self] in
                        self?.sendRequestWithRetry(
                            url: url,
                            retryCount: retryCount + 1,
                            completion: completion
                        )
                    }
                } else {
                    completion(.failure(.timeout))
                }
            } catch {
                completion(.failure(.decodingError))
            }
        }

        currentTask?.resume()
    }

    func cancelRequest() {
        currentTask?.cancel()
        currentTask = nil
    }
}

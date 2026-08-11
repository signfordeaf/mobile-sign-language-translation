// Network/SignLanguageAPIService.swift

import Foundation

/// The outcome of a `/Translate` call (docs/03-api-contract.md).
enum TranslateOutcome {
    /// The backend returned a ready translation (`state: true`).
    case success(SignModel)
    /// The request was cancelled by the caller.
    case cancelled
    /// The request failed — no usable video, transport failure, or exhausted polling.
    case failure(SignForDeafError)
}

/// A handle that cancels an in-flight translate call.
protocol TranslateCancellable: AnyObject {
    func cancel()
}

/// The network seam the controller talks to. Injectable so the state machine can
/// be tested without a live backend.
protocol TranslateService: AnyObject {
    /// Start a `/Translate` call for `text` under the given ids. `completion` runs
    /// exactly once. The returned handle cancels just this call.
    @discardableResult
    func translate(
        text: String, tid: String, fdid: String,
        completion: @escaping (TranslateOutcome) -> Void
    ) -> TranslateCancellable
}

/// URLSession client that polls the `/Translate` endpoint until a sign language
/// video is ready (docs/03-api-contract.md §Polling).
final class SignLanguageAPIService: TranslateService {

    private let config: SignForDeafConfig
    private let maxRetries: Int = 30
    private let retryDelay: TimeInterval = 1.0

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
    }()

    init(config: SignForDeafConfig) {
        self.config = config
    }

    /// One translate call, with its own polling loop and cancellation flag.
    private final class Handle: TranslateCancellable {
        private let lock = NSLock()
        private var task: URLSessionDataTask?
        private var isCancelled = false

        func setTask(_ t: URLSessionDataTask) {
            lock.lock(); defer { lock.unlock() }
            if isCancelled { t.cancel() } else { task = t }
        }
        var cancelled: Bool {
            lock.lock(); defer { lock.unlock() }
            return isCancelled
        }
        func cancel() {
            lock.lock(); defer { lock.unlock() }
            isCancelled = true
            task?.cancel()
            task = nil
        }
    }

    @discardableResult
    func translate(
        text: String, tid: String, fdid: String,
        completion: @escaping (TranslateOutcome) -> Void
    ) -> TranslateCancellable {
        let handle = Handle()
        guard var components = URLComponents(string: "\(config.apiUrl)/Translate") else {
            completion(.failure(SignForDeafError(code: .apiError, message: "Invalid API URL")))
            return handle
        }
        components.queryItems = [
            URLQueryItem(name: "s", value: text),
            URLQueryItem(name: "rk", value: config.apiKey),
            URLQueryItem(name: "fdid", value: fdid),
            URLQueryItem(name: "tid", value: tid),
            URLQueryItem(name: "language", value: config.language.apiCode),
            URLQueryItem(name: "url", value: config.originUrl),
        ]
        guard let url = components.url else {
            completion(.failure(SignForDeafError(code: .apiError, message: "Invalid request URL")))
            return handle
        }
        send(url: url, retry: 0, handle: handle, completion: completion)
        return handle
    }

    private func send(
        url: URL, retry: Int, handle: Handle,
        completion: @escaping (TranslateOutcome) -> Void
    ) {
        if handle.cancelled { completion(.cancelled); return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(config.originUrl, forHTTPHeaderField: "Origin")

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if handle.cancelled { completion(.cancelled); return }

            if let nsError = error as NSError?, nsError.code == NSURLErrorCancelled {
                completion(.cancelled)
                return
            }
            if error != nil {
                completion(.failure(SignForDeafError(code: .networkError, message: "Request failed")))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(SignForDeafError(code: .apiError, message: "Invalid response")))
                return
            }
            guard (200...299).contains(http.statusCode) else {
                completion(.failure(SignForDeafError(
                    code: .apiError, message: "HTTP \(http.statusCode)")))
                return
            }
            guard let data = data else {
                completion(.failure(SignForDeafError(code: .apiError, message: "No data")))
                return
            }
            do {
                let model = try JSONDecoder().decode(SignModel.self, from: data)
                if model.state == true {
                    completion(.success(model))
                } else if retry < self.maxRetries {
                    // Still rendering — repeat the same request after a short delay.
                    DispatchQueue.global().asyncAfter(deadline: .now() + self.retryDelay) { [weak self] in
                        self?.send(url: url, retry: retry + 1, handle: handle, completion: completion)
                    }
                } else {
                    completion(.failure(SignForDeafError(
                        code: .apiError, message: "No translation available (polling exhausted)")))
                }
            } catch {
                completion(.failure(SignForDeafError(code: .apiError, message: "Decode failed")))
            }
        }
        handle.setTask(task)
        task.resume()
    }
}

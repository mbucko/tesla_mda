import Foundation
import MDACore

/// Fetches with the system networking stack. tesla.com sits behind Akamai bot protection,
/// which rejects curl's TLS fingerprint but accepts URLSession's (the same stack Safari uses).
struct URLSessionHTTPClient: HTTPClient {
    enum Failure: LocalizedError {
        case badStatus(Int, URL)
        case undecodable(URL)

        var errorDescription: String? {
            switch self {
            case let .badStatus(code, url): "HTTP \(code) from \(url.host ?? url.absoluteString)"
            case let .undecodable(url): "Unreadable response from \(url.host ?? url.absoluteString)"
            }
        }
    }

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9",
        ]
        session = URLSession(configuration: configuration)
    }

    func fetchText(from url: URL) async throws -> String {
        let (data, response) = try await session.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw Failure.badStatus(status, url) }
        guard let text = String(data: data, encoding: .utf8) else { throw Failure.undecodable(url) }
        return text
    }
}

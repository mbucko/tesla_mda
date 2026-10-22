import Foundation

public protocol HTTPClient: Sendable {
    func fetchText(from url: URL) async throws -> String
}

public enum ConstantsServiceError: Error, Equatable, LocalizedError {
    case counterNotFound

    public var errorDescription: String? {
        switch self {
        case .counterNotFound: "Couldn't find the miles counter on Tesla's page"
        }
    }
}

/// Fetches the safety page and finds the counter constants in one of its scripts.
public struct ConstantsService: Sendable {
    public static let defaultPageURL = URL(string: "https://www.tesla.com/robotaxi/safety")!

    private let client: HTTPClient
    private let pageURL: URL

    public init(client: HTTPClient, pageURL: URL = defaultPageURL) {
        self.client = client
        self.pageURL = pageURL
    }

    public func fetchSnapshot(now: Date = Date()) async throws -> CounterSnapshot {
        let html = try await client.fetchText(from: pageURL)

        // The counter constants live in one of the page's own scripts; third-party scripts are skipped.
        let candidates = ConstantsParser.scriptURLs(fromHTML: html, baseURL: pageURL)
            .filter { $0.host == pageURL.host }
        for url in candidates {
            guard let script = try? await client.fetchText(from: url) else { continue }
            if let constants = ConstantsParser.parseConstants(fromScript: script) {
                return CounterSnapshot(constants: constants, source: .formula, fetchedAt: now)
            }
        }

        // Tesla renamed or moved the formula: fall back to the static figure so the number stays correct-ish.
        if let miles = ConstantsParser.parseStaticMiles(fromHTML: html) {
            let constants = CounterConstants(startMiles: miles, startDate: now, milesPerMillisecond: 0)
            return CounterSnapshot(constants: constants, source: .staticFigure, fetchedAt: now)
        }
        throw ConstantsServiceError.counterNotFound
    }
}

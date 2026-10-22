import Foundation
import Testing
@testable import MDACore

struct FakeHTTPClient: HTTPClient {
    var responses: [String: String]

    func fetchText(from url: URL) async throws -> String {
        guard let body = responses[url.absoluteString] else { throw URLError(.fileDoesNotExist) }
        return body
    }
}

@Suite struct ConstantsServiceTests {
    let page = ConstantsService.defaultPageURL.absoluteString
    let header = "https://www.tesla.com/assets/js/js_header.js?scope=header&delta=0"
    let footer = "https://www.tesla.com/assets/js/js_footer.js?scope=footer&delta=0"
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func findsConstantsInFirstMatchingScript() async throws {
        let client = FakeHTTPClient(responses: [page: pageExcerpt, header: "var x = 1;", footer: counterScriptExcerpt])
        let snapshot = try await ConstantsService(client: client).fetchSnapshot(now: now)
        #expect(snapshot.source == .formula)
        #expect(snapshot.constants.startMiles == 3_112_541)
        #expect(snapshot.fetchedAt == now)
    }

    @Test func skipsScriptsThatFailToLoad() async throws {
        let client = FakeHTTPClient(responses: [page: pageExcerpt, footer: counterScriptExcerpt])
        let snapshot = try await ConstantsService(client: client).fetchSnapshot(now: now)
        #expect(snapshot.source == .formula)
    }

    @Test func fallsBackToStaticFigureWhenFormulaIsMissing() async throws {
        let client = FakeHTTPClient(responses: [page: pageExcerpt, header: "", footer: ""])
        let snapshot = try await ConstantsService(client: client).fetchSnapshot(now: now)
        #expect(snapshot.source == .staticFigure)
        #expect(snapshot.constants.miles(at: now.addingTimeInterval(3600)) == 3_112_541)
    }

    @Test func throwsWhenPageHasNoCounter() async {
        let client = FakeHTTPClient(responses: [page: "<html></html>"])
        await #expect(throws: ConstantsServiceError.counterNotFound) {
            try await ConstantsService(client: client).fetchSnapshot(now: now)
        }
    }

    @Test func propagatesPageFetchFailure() async {
        let client = FakeHTTPClient(responses: [:])
        await #expect(throws: URLError.self) {
            try await ConstantsService(client: client).fetchSnapshot(now: now)
        }
    }
}

import Foundation
import Testing
@testable import MDACore

/// Excerpt of tesla.com's counter script, as served on 2026-10-21.
let counterScriptExcerpt = """
    const totalMilesStart = 12445140996;
    const startEpochTime = new Date('2026-07-18T08:14:00Z').getTime();
    // DWP-22979: Robotaxi FSD miles (3,112,541 mi as of 10/18/2026 23:59:59 CT)
    const robotaxiMilesStart = 3112541;
    const robotaxiStartEpochTime = new Date('2026-10-19T04:59:59Z').getTime();
    const robotaxiMilesPerMillisecond = 0.0009221;
    """

/// Excerpt of the page HTML: the figure appears JSON-escaped in a data blob, and script tags use &amp;.
let pageExcerpt = """
    <script type="application/json">{"component_right_header_line_1":{"t_value":"<span id=\\"robotaxi-fsd-distance\\">3,112,541<\\/span>"}}</script>
    <script src="/assets/js/js_header.js?scope=header&amp;delta=0"></script>
    <script src="https://cdn.example.com/analytics.js"></script>
    <script src="/assets/js/js_footer.js?scope=footer&amp;delta=0"></script>
    """

let robotaxiStart = ISO8601DateFormatter().date(from: "2026-10-19T04:59:59Z")!

@Suite struct ConstantsParserTests {
    @Test func parsesConstantsFromCounterScript() throws {
        let constants = try #require(ConstantsParser.parseConstants(fromScript: counterScriptExcerpt))
        #expect(constants.startMiles == 3_112_541)
        #expect(constants.startDate == robotaxiStart)
        #expect(constants.milesPerMillisecond == 0.0009221)
    }

    @Test func returnsNilWhenAnyConstantIsMissing() {
        let withoutRate = counterScriptExcerpt.replacingOccurrences(of: "robotaxiMilesPerMillisecond", with: "renamed")
        #expect(ConstantsParser.parseConstants(fromScript: withoutRate) == nil)
        #expect(ConstantsParser.parseConstants(fromScript: "console.log('hi')") == nil)
    }

    @Test func parsesEscapedStaticFigure() {
        #expect(ConstantsParser.parseStaticMiles(fromHTML: pageExcerpt) == 3_112_541)
    }

    @Test func parsesRenderedStaticFigure() {
        let html = #"<span id="robotaxi-fsd-distance" style="display: inline-block;">3,351,006</span>"#
        #expect(ConstantsParser.parseStaticMiles(fromHTML: html) == 3_351_006)
    }

    @Test func resolvesAndUnescapesScriptURLs() {
        let urls = ConstantsParser.scriptURLs(fromHTML: pageExcerpt, baseURL: ConstantsService.defaultPageURL)
        #expect(urls.map(\.absoluteString) == [
            "https://www.tesla.com/assets/js/js_header.js?scope=header&delta=0",
            "https://cdn.example.com/analytics.js",
            "https://www.tesla.com/assets/js/js_footer.js?scope=footer&delta=0",
        ])
    }
}

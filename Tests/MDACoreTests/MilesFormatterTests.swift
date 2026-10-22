import Foundation
import Testing
@testable import MDACore

@Suite struct MilesFormatterTests {
    let us = Locale(identifier: "en_US")

    @Test(arguments: [
        (DisplayFormat.compact2, 3_351_066.7, "3.35M"),
        (.compact2, 3_999_999, "3.99M"),
        (.compact2, 4_000_000, "4.00M"),
        (.compact3, 3_351_066, "3.351M"),
        (.full, 3_351_066.9, "3,351,066"),
        (.compact2, 12_445_140_996, "12.44B"),
        (.compact2, 950, "950"),
    ])
    func formats(format: DisplayFormat, miles: Double, expected: String) {
        #expect(MilesFormatter(format: format, locale: us).string(for: miles) == expected)
    }

    @Test func appendsUnit() {
        #expect(MilesFormatter(format: .compact2, showUnit: true, locale: us).string(for: 3_351_066) == "3.35M mi")
    }
}

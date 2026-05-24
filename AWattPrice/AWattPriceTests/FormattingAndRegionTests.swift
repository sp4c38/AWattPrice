import XCTest
@testable import AWattPrice

final class FormattingAndRegionTests: XCTestCase {
    func testMarketAreaFallbackAndLabels() {
        XCTAssertEqual(MarketArea.area(for: "AT"), .austria)
        XCTAssertEqual(MarketArea.area(for: "unknown"), .germanyLuxembourg)
        XCTAssertEqual(MarketArea.germanyLuxembourg.settingsFlag, "DE")
        XCTAssertEqual(MarketArea.austria.settingsFlag, "AT")
    }

    func testStringDoubleValueAcceptsCommaAndDotSeparators() throws {
        XCTAssertEqual(try XCTUnwrap("12,5".doubleValue), 12.5, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap("12.5".doubleValue), 12.5, accuracy: 0.0001)
        XCTAssertNil("abc".doubleValue)
    }

    func testPriceStringFormatting() {
        XCTAssertNotNil(12.priceString)
        XCTAssertNotNil(12.345.priceString)
        XCTAssertEqual(0.004.priceString, "")
        XCTAssertEqual(100.0.euroMWhToCentkWh, 10, accuracy: 0.0001)
    }

    func testTotalTimeFormatterUsesCompactTimeUnits() {
        let formatter = TotalTimeFormatter()

        XCTAssertEqual(formatter.string(hour: 2, minute: 30), "2h, 30min")
        XCTAssertEqual(formatter.string(hour: 2, minute: 0), "2h")
        XCTAssertEqual(formatter.string(hour: 0, minute: 30), "30min")
        XCTAssertEqual(formatter.string(hour: 0, minute: 0), "<1min")
    }
}

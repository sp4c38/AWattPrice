import XCTest
@testable import AWattPrice

final class WidgetPriceSnapshotTests: XCTestCase {
    func testSnapshotSortsPointsAndCalculatesSummaryValues() throws {
        let snapshot = WidgetPriceSnapshot(
            createdAt: Self.base.addingTimeInterval(30 * 60),
            marketAreaName: "Deutschland / Luxemburg",
            points: [
                Self.point(hour: 2, price: 30),
                Self.point(hour: 0, price: 10),
                Self.point(hour: 1, price: 20),
            ]
        )

        XCTAssertEqual(snapshot.points.map(\WidgetPricePoint.marketprice), [10, 20, 30])
        XCTAssertEqual(snapshot.currentPrice?.marketprice, 10)
        XCTAssertEqual(try XCTUnwrap(snapshot.averagePrice), 20, accuracy: 0.0001)
        XCTAssertEqual(snapshot.minPrice?.marketprice, 10)
        XCTAssertEqual(snapshot.maxPrice?.marketprice, 30)
        XCTAssertEqual(snapshot.priceStep, 60 * 60)
        XCTAssertTrue(snapshot.hasPrices)
    }

    func testSnapshotCalculatesWeightedHourlyForecast() throws {
        let snapshot = WidgetPriceSnapshot(
            createdAt: Self.base,
            marketAreaName: "Deutschland / Luxemburg",
            points: [
                Self.point(startMinutes: 0, endMinutes: 15, price: 10),
                Self.point(startMinutes: 15, endMinutes: 60, price: 30),
                Self.point(startMinutes: 60, endMinutes: 120, price: 20),
            ]
        )

        XCTAssertEqual(snapshot.hourlyForecastPoints.count, 2)
        XCTAssertEqual(snapshot.hourlyForecastPoints[0].marketprice, 25, accuracy: 0.0001)
        XCTAssertEqual(snapshot.hourlyForecastPoints[1].marketprice, 20, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(snapshot.hourlyForecastAveragePrice), 22.5, accuracy: 0.0001)
        XCTAssertEqual(snapshot.hourlyForecastMinPrice?.marketprice, 20)
        XCTAssertEqual(snapshot.hourlyForecastMaxPrice?.marketprice, 25)
        XCTAssertEqual(snapshot.currentHourlyForecastPrice?.marketprice, 25)
    }

    func testSnapshotFindsCheapestWindowsForExpectedDurations() throws {
        let snapshot = WidgetPriceSnapshot(
            createdAt: Self.base,
            marketAreaName: "Deutschland / Luxemburg",
            points: [
                Self.point(hour: 0, price: 30),
                Self.point(hour: 1, price: 5),
                Self.point(hour: 2, price: 10),
                Self.point(hour: 3, price: 40),
                Self.point(hour: 4, price: 1),
            ]
        )

        let windowsByDuration: [TimeInterval: WidgetPriceWindow] = Dictionary(uniqueKeysWithValues: snapshot.cheapestWindows.map { ($0.duration, $0) })

        XCTAssertEqual(windowsByDuration[60 * 60]?.startTime, Self.base.addingTimeInterval(4 * 60 * 60))
        XCTAssertEqual(windowsByDuration[2 * 60 * 60]?.startTime, Self.base.addingTimeInterval(60 * 60))
        XCTAssertEqual(try XCTUnwrap(windowsByDuration[2 * 60 * 60]).averagePrice, 7.5, accuracy: 0.0001)
        XCTAssertEqual(windowsByDuration[4 * 60 * 60]?.startTime, Self.base.addingTimeInterval(60 * 60))
        XCTAssertEqual(try XCTUnwrap(windowsByDuration[4 * 60 * 60]).averagePrice, 14, accuracy: 0.0001)
    }

    func testEmptySnapshotHasNoPriceSummaries() {
        let snapshot = WidgetPriceSnapshot(createdAt: Self.base, marketAreaName: "Deutschland / Luxemburg", points: [])

        XCTAssertFalse(snapshot.hasPrices)
        XCTAssertNil(snapshot.currentPrice)
        XCTAssertNil(snapshot.averagePrice)
        XCTAssertNil(snapshot.minPrice)
        XCTAssertNil(snapshot.maxPrice)
        XCTAssertEqual(snapshot.priceStep, 60 * 60)
        XCTAssertEqual(snapshot.cheapestWindows.count, 0)
    }

    private static let base = Date(timeIntervalSince1970: 4_102_444_800)

    private static func point(hour: Int, price: Double) -> WidgetPricePoint {
        WidgetPricePoint(
            startTime: base.addingTimeInterval(TimeInterval(hour * 60 * 60)),
            endTime: base.addingTimeInterval(TimeInterval((hour + 1) * 60 * 60)),
            marketprice: price
        )
    }

    private static func point(startMinutes: Int, endMinutes: Int, price: Double) -> WidgetPricePoint {
        WidgetPricePoint(
            startTime: base.addingTimeInterval(TimeInterval(startMinutes * 60)),
            endTime: base.addingTimeInterval(TimeInterval(endMinutes * 60)),
            marketprice: price
        )
    }
}

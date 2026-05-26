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

    func testSnapshotCalculatesRisingNextThreeHourTrend() {
        let snapshot = WidgetPriceSnapshot(
            createdAt: Self.base.addingTimeInterval(30 * 60),
            marketAreaName: "Deutschland / Luxemburg",
            points: [
                Self.point(hour: 0, price: 10),
                Self.point(hour: 1, price: 11),
                Self.point(hour: 2, price: 12),
            ]
        )

        XCTAssertEqual(snapshot.nextThreeHourTrend, .rising)
    }

    func testSnapshotCalculatesFallingNextThreeHourTrend() {
        let snapshot = WidgetPriceSnapshot(
            createdAt: Self.base.addingTimeInterval(30 * 60),
            marketAreaName: "Deutschland / Luxemburg",
            points: [
                Self.point(hour: 0, price: 12),
                Self.point(hour: 1, price: 11),
                Self.point(hour: 2, price: 10),
            ]
        )

        XCTAssertEqual(snapshot.nextThreeHourTrend, .falling)
    }

    func testSnapshotCalculatesStableNextThreeHourTrend() {
        let snapshot = WidgetPriceSnapshot(
            createdAt: Self.base.addingTimeInterval(30 * 60),
            marketAreaName: "Deutschland / Luxemburg",
            points: [
                Self.point(hour: 0, price: 10),
                Self.point(hour: 1, price: 10.2),
                Self.point(hour: 2, price: 10.1),
            ]
        )

        XCTAssertEqual(snapshot.nextThreeHourTrend, .stable)
    }

    func testSnapshotHasNoNextThreeHourTrendWithInsufficientData() {
        let snapshot = WidgetPriceSnapshot(
            createdAt: Self.base.addingTimeInterval(30 * 60),
            marketAreaName: "Deutschland / Luxemburg",
            points: [
                Self.point(hour: 0, price: 10),
            ]
        )

        XCTAssertNil(snapshot.nextThreeHourTrend)
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

    func testGenerationMixSnapshotSortsAndFiltersCategories() {
        let snapshot = Self.generationMixSnapshot(
            categories: [
                WidgetGenerationMixCategory(category: "fossil", generationMW: 10, share: 10, isRenewable: false),
                WidgetGenerationMixCategory(category: "hydro", generationMW: 20, share: 20, isRenewable: true),
                WidgetGenerationMixCategory(category: "solar", generationMW: 20, share: 20, isRenewable: true),
                WidgetGenerationMixCategory(category: "wind", generationMW: 0, share: 0, isRenewable: true),
            ]
        )

        XCTAssertEqual(snapshot.visibleCategories.map(\.category), ["solar", "hydro", "fossil"])
        XCTAssertEqual(snapshot.orderedCategories.map(\.category), ["solar", "hydro", "fossil"])
        XCTAssertTrue(snapshot.hasMix)
    }

    func testGenerationMixSnapshotPreservesSummaryValues() {
        let snapshot = Self.generationMixSnapshot()

        XCTAssertEqual(snapshot.marketAreaName, "Deutschland / Luxemburg")
        XCTAssertEqual(snapshot.updatedAt, Self.base)
        XCTAssertEqual(snapshot.startTime, Self.base)
        XCTAssertEqual(snapshot.endTime, Self.base.addingTimeInterval(60 * 60))
        XCTAssertEqual(snapshot.totalGenerationMW, 100)
        XCTAssertEqual(snapshot.renewableGenerationMW, 64)
        XCTAssertEqual(snapshot.renewableShare, 64)
    }

    func testGenerationMixSnapshotCodableRoundTrip() throws {
        let snapshot = Self.generationMixSnapshot()
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WidgetGenerationMixSnapshot.self, from: data)

        XCTAssertEqual(decoded.marketAreaName, snapshot.marketAreaName)
        XCTAssertEqual(decoded.renewableShare, snapshot.renewableShare)
        XCTAssertEqual(decoded.visibleCategories.map(\.category), snapshot.visibleCategories.map(\.category))
    }

    func testEmptyGenerationMixSnapshotIsUnavailable() {
        let snapshot = WidgetGenerationMixSnapshot(
            createdAt: Self.base,
            marketAreaName: "Deutschland / Luxemburg",
            updatedAt: Self.base,
            startTime: Self.base,
            endTime: Self.base,
            totalGenerationMW: 0,
            renewableGenerationMW: 0,
            renewableShare: 0,
            categories: []
        )

        XCTAssertFalse(snapshot.hasMix)
        XCTAssertEqual(snapshot.visibleCategories.count, 0)
        XCTAssertEqual(snapshot.orderedCategories.count, 0)
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

    private static func generationMixSnapshot(
        categories: [WidgetGenerationMixCategory] = [
            WidgetGenerationMixCategory(category: "solar", generationMW: 22, share: 22, isRenewable: true),
            WidgetGenerationMixCategory(category: "wind", generationMW: 34, share: 34, isRenewable: true),
            WidgetGenerationMixCategory(category: "hydro", generationMW: 8, share: 8, isRenewable: true),
            WidgetGenerationMixCategory(category: "fossil", generationMW: 36, share: 36, isRenewable: false),
        ]
    ) -> WidgetGenerationMixSnapshot {
        WidgetGenerationMixSnapshot(
            createdAt: base,
            marketAreaName: "Deutschland / Luxemburg",
            updatedAt: base,
            startTime: base,
            endTime: base.addingTimeInterval(60 * 60),
            totalGenerationMW: 100,
            renewableGenerationMW: 64,
            renewableShare: 64,
            categories: categories
        )
    }
}

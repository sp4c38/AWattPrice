import XCTest
@testable import AWattPrice

final class EnergyDataTests: XCTestCase {
    func testEnergyPricePointDecodesServerPriceToCentPerKilowattHour() throws {
        let point = try Self.decodePricePoint(start: 4_102_444_800, end: 4_102_448_400, marketprice: 123.45)

        XCTAssertEqual(point.startTime.timeIntervalSince1970, 4_102_444_800)
        XCTAssertEqual(point.endTime.timeIntervalSince1970, 4_102_448_400)
        XCTAssertEqual(point.marketprice, 12.345, accuracy: 0.0001)
    }

    func testEnergyPricePointNormalizesNegativeZero() throws {
        let point = try Self.decodePricePoint(start: 4_102_444_800, end: 4_102_448_400, marketprice: -0.0)

        XCTAssertEqual(point.marketprice, 0)
        XCTAssertEqual(point.marketprice.sign, .plus)
    }

    func testComputeValuesAppliesTaxAndOrderedAddOns() throws {
        var data = try Self.decodeEnergyData(
            """
            {
              "area": "DE-LU",
              "resolution": "PT60M",
              "prices": [
                { "start_timestamp": 4102444800, "end_timestamp": 4102448400, "marketprice": 100 },
                { "start_timestamp": 4102448400, "end_timestamp": 4102452000, "marketprice": -50 },
                { "start_timestamp": 4102452000, "end_timestamp": 4102455600, "marketprice": 200 }
              ]
            }
            """
        )
        let configuration = PricingConfiguration(
            fixedPriceAddOn: 0,
            percentagePriceAddOn: 0,
            taxEnabled: true,
            orderedAddOns: [
                PriceAddOnConfiguration(kind: .tax, value: 0),
                PriceAddOnConfiguration(kind: .fixed, value: 2),
                PriceAddOnConfiguration(kind: .percentage, value: 10),
                PriceAddOnConfiguration(kind: .monthly, value: 1),
            ],
            marketArea: .germanyLuxembourg
        )

        data.computeValues(with: configuration)

        XCTAssertEqual(data.currentPrices.count, 3)
        XCTAssertEqual(data.currentPrices[0].marketprice, 16.29, accuracy: 0.0001)
        XCTAssertEqual(data.currentPrices[1].marketprice, -2.3, accuracy: 0.0001)
        XCTAssertEqual(data.currentPrices[2].marketprice, 29.38, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(data.minCostPricePoint).marketprice, -2.3, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(data.maxCostPricePoint).marketprice, 29.38, accuracy: 0.0001)
        let timeRange = try XCTUnwrap(data.minMaxTimeRange)
        XCTAssertEqual(timeRange.lowerBound.timeIntervalSince1970, 4_102_444_800)
        XCTAssertEqual(timeRange.upperBound.timeIntervalSince1970, 4_102_455_600)
    }

    func testComputeValuesSkipsTaxWhenDisabled() throws {
        var data = try Self.decodeEnergyData(
            """
            {
              "area": "DE-LU",
              "resolution": "PT60M",
              "prices": [
                { "start_timestamp": 4102444800, "end_timestamp": 4102448400, "marketprice": 100 }
              ]
            }
            """
        )
        let configuration = PricingConfiguration(
            fixedPriceAddOn: 0,
            percentagePriceAddOn: 0,
            taxEnabled: false,
            orderedAddOns: [],
            marketArea: .germanyLuxembourg
        )

        data.computeValues(with: configuration)

        XCTAssertEqual(try XCTUnwrap(data.currentPrices.first).marketprice, 10, accuracy: 0.0001)
    }

    func testComputeValuesCanIncludeHistoricalPrices() throws {
        var data = try Self.decodeEnergyData(
            """
            {
              "area": "DE-LU",
              "resolution": "PT60M",
              "prices": [
                { "start_timestamp": 946684800, "end_timestamp": 946688400, "marketprice": 100 }
              ]
            }
            """
        )

        data.computeValues(
            with: PricingConfiguration(
                fixedPriceAddOn: 0,
                percentagePriceAddOn: 0,
                taxEnabled: true,
                orderedAddOns: [PriceAddOnConfiguration(kind: .tax, value: 0)],
                marketArea: .austria
            ),
            includesPastPrices: true
        )

        XCTAssertEqual(data.currentPrices.count, 1)
        XCTAssertEqual(try XCTUnwrap(data.currentPrices.first).marketprice, 12, accuracy: 0.0001)
    }

    func testGenerationMixOrderingFiltersEmptyCategories() throws {
        let data = try GenerationMixData.jsonDecoder().decode(
            GenerationMixData.self,
            from: Data(
                """
                {
                  "area": "DE-LU",
                  "resolution": "PT60M",
                  "updated_at": 4102444800,
                  "start_timestamp": 4102444800,
                  "end_timestamp": 4102448400,
                  "total_generation_mw": 100,
                  "renewable_generation_mw": 50,
                  "renewable_share": 50,
                  "categories": [
                    { "category": "fossil", "generation_mw": 10, "share": 10, "is_renewable": false },
                    { "category": "solar", "generation_mw": 20, "share": 20, "is_renewable": true },
                    { "category": "hydro", "generation_mw": 20, "share": 20, "is_renewable": true },
                    { "category": "wind", "generation_mw": 0, "share": 0, "is_renewable": true }
                  ]
                }
                """.utf8
            )
        )

        XCTAssertEqual(data.visibleCategories.map(\.category), ["solar", "hydro", "fossil"])
        XCTAssertEqual(data.orderedCategories.map(\.category), ["solar", "hydro", "fossil"])
    }

    func testGenerationMixHistoryDecodesUnchangedPayload() throws {
        let data = try GenerationMixHistoryData.jsonDecoder().decode(
            GenerationMixHistoryData.self,
            from: Data(
                """
                {
                  "area": "DE-LU",
                  "resolution": "PT60M",
                  "updated_at": 4102444800,
                  "start_timestamp": 4102444800,
                  "end_timestamp": 4102448400,
                  "total_generation_mw": 100,
                  "renewable_generation_mw": 50,
                  "renewable_share": 50,
                  "categories": [
                    { "category": "solar", "generation_mw": 50, "share": 50, "is_renewable": true },
                    { "category": "fossil", "generation_mw": 50, "share": 50, "is_renewable": false }
                  ],
                  "intervals": [
                    {
                      "start_timestamp": 4102444800,
                      "end_timestamp": 4102448400,
                      "total_generation_mw": 100,
                      "renewable_generation_mw": 50,
                      "renewable_share": 50,
                      "categories": [
                        { "category": "solar", "generation_mw": 50, "share": 50, "is_renewable": true },
                        { "category": "fossil", "generation_mw": 50, "share": 50, "is_renewable": false }
                      ]
                    }
                  ]
                }
                """.utf8
            )
        )

        XCTAssertEqual(data.intervals.count, 1)
        XCTAssertEqual(data.renewableShare, 50)
        XCTAssertEqual(data.sortedIntervals.first?.visibleCategories.map(\.category), ["solar", "fossil"])
        XCTAssertFalse(data.sortedIntervals.first?.isPartialPublication ?? true)
        XCTAssertFalse(data.isPartialPublication)
        XCTAssertNil(data.latestCompleteEndTime)
        XCTAssertNil(data.latestPublishedEndTime)
    }

    func testGenerationMixHistoryDecodesPartialPublicationMetadata() throws {
        let history = try GenerationMixHistoryData.jsonDecoder().decode(
            GenerationMixHistoryData.self,
            from: Data(
                """
                {
                  "area": "DE-LU",
                  "resolution": "PT60M",
                  "updated_at": 4102444800,
                  "start_timestamp": 4102444800,
                  "end_timestamp": 4102455600,
                  "total_generation_mw": 100,
                  "renewable_generation_mw": 50,
                  "renewable_share": 50,
                  "is_partial_publication": true,
                  "latest_complete_end_timestamp": 4102448400,
                  "latest_published_end_timestamp": 4102455600,
                  "categories": [
                    { "category": "solar", "generation_mw": 50, "share": 50, "is_renewable": true },
                    { "category": "fossil", "generation_mw": 50, "share": 50, "is_renewable": false }
                  ],
                  "intervals": [
                    {
                      "start_timestamp": 4102444800,
                      "end_timestamp": 4102448400,
                      "total_generation_mw": 100,
                      "renewable_generation_mw": 50,
                      "renewable_share": 50,
                      "categories": [
                        { "category": "solar", "generation_mw": 50, "share": 50, "is_renewable": true },
                        { "category": "fossil", "generation_mw": 50, "share": 50, "is_renewable": false }
                      ]
                    },
                    {
                      "start_timestamp": 4102448400,
                      "end_timestamp": 4102455600,
                      "total_generation_mw": 10,
                      "renewable_generation_mw": 0,
                      "renewable_share": 0,
                      "is_partial_publication": true,
                      "categories": [
                        { "category": "fossil", "generation_mw": 10, "share": 100, "is_renewable": false }
                      ]
                    }
                  ]
                }
                """.utf8
            )
        )
        let recentData = GenerationMixData(
            history: history,
            referenceDate: Date(timeIntervalSince1970: 4_102_455_600 + (119 * 60))
        )
        let matureData = GenerationMixData(
            history: history,
            referenceDate: Date(timeIntervalSince1970: 4_102_455_600 + (120 * 60))
        )

        XCTAssertTrue(history.isPartialPublication)
        XCTAssertFalse(history.sortedIntervals[0].isPartialPublication)
        XCTAssertTrue(history.sortedIntervals[1].isPartialPublication)
        XCTAssertEqual(history.latestCompleteEndTime?.timeIntervalSince1970, 4_102_448_400)
        XCTAssertEqual(history.latestPublishedEndTime?.timeIntervalSince1970, 4_102_455_600)
        XCTAssertFalse(recentData.isPartialPublication)
        XCTAssertTrue(matureData.isPartialPublication)
        XCTAssertEqual(matureData.endTime.timeIntervalSince1970, 4_102_448_400)
        XCTAssertEqual(matureData.renewableShare, 50)
        XCTAssertEqual(matureData.latestPublishedEndTime?.timeIntervalSince1970, 4_102_455_600)
    }

    func testGenerationMixPartialPublicationVisibilityDelay() {
        let referenceDate = Date(timeIntervalSince1970: 10_000)
        let categories: [GenerationMixCategory] = []
        let completeInterval = GenerationMixInterval(
            startTime: referenceDate.addingTimeInterval(-15 * 60),
            endTime: referenceDate,
            totalGenerationMW: 100,
            renewableGenerationMW: 50,
            renewableShare: 50,
            categories: categories
        )
        let recentPartialInterval = GenerationMixInterval(
            startTime: referenceDate.addingTimeInterval(-134 * 60),
            endTime: referenceDate.addingTimeInterval(-119 * 60),
            totalGenerationMW: 10,
            renewableGenerationMW: 0,
            renewableShare: 0,
            categories: categories,
            isPartialPublication: true
        )
        let maturePartialInterval = GenerationMixInterval(
            startTime: referenceDate.addingTimeInterval(-135 * 60),
            endTime: referenceDate.addingTimeInterval(-120 * 60),
            totalGenerationMW: 10,
            renewableGenerationMW: 0,
            renewableShare: 0,
            categories: categories,
            isPartialPublication: true
        )

        XCTAssertTrue(completeInterval.shouldBeVisible(referenceDate: referenceDate))
        XCTAssertFalse(recentPartialInterval.shouldBeVisible(referenceDate: referenceDate))
        XCTAssertTrue(maturePartialInterval.shouldBeVisible(referenceDate: referenceDate))
    }

    private static func decodePricePoint(start: Int, end: Int, marketprice: Double) throws -> EnergyPricePoint {
        try EnergyData.jsonDecoder().decode(
            EnergyPricePoint.self,
            from: Data(
                """
                {
                  "start_timestamp": \(start),
                  "end_timestamp": \(end),
                  "marketprice": \(marketprice)
                }
                """.utf8
            )
        )
    }

    private static func decodeEnergyData(_ json: String) throws -> EnergyData {
        try EnergyData.jsonDecoder().decode(EnergyData.self, from: Data(json.utf8))
    }
}

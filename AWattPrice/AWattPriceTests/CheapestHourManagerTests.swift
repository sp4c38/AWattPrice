import XCTest
@testable import AWattPrice

final class CheapestHourManagerTests: XCTestCase {
    func testValidateInputsFlagsUsageLongerThanSelectedRange() {
        let manager = CheapestHourManager()
        manager.startDate = Date(timeIntervalSince1970: 0)
        manager.endDate = Date(timeIntervalSince1970: 60 * 60)
        manager.timeOfUsageInterval = 2 * 60 * 60

        manager.validateInputs()

        XCTAssertFalse(manager.hasValidInput)
        XCTAssertTrue(manager.showsTimeRangeError)
    }

    func testCreateHourPairsOnlyReturnsWindowsInsideSelectedRange() {
        let manager = CheapestHourManager()
        let data = Self.energyData(prices: [30, 10, 20, 5])
        let pairs = manager.createHourPairs(
            forHours: 2,
            fromStartTime: Self.base.addingTimeInterval(60 * 60),
            toEndTime: Self.base.addingTimeInterval(4 * 60 * 60),
            with: data
        )

        XCTAssertEqual(pairs.count, 2)
        XCTAssertEqual(pairs.count, 2)
        XCTAssertEqual(pairs[0].averagePrice, 15, accuracy: 0.0001)
        XCTAssertEqual(pairs[1].averagePrice, 12.5, accuracy: 0.0001)
        XCTAssertEqual(manager.compareHourPairs(allPairs: pairs), 1)
    }

    func testCalculateCheapestHoursChoosesLowestAverageWindow() {
        let manager = CheapestHourManager()
        manager.startDate = Self.base
        manager.endDate = Self.base.addingTimeInterval(4 * 60 * 60)
        manager.timeOfUsage = 2 * 60 * 60
        let data = Self.energyData(prices: [30, 10, 20, 5])

        manager.calculateCheapestHours(energyData: data)

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in manager.result != nil || manager.failedToFindResult },
            object: nil
        )
        wait(for: [expectation], timeout: 2)

        XCTAssertEqual(manager.result?.startDate, Self.base.addingTimeInterval(2 * 60 * 60))
        XCTAssertEqual(manager.result?.endDate, Self.base.addingTimeInterval(4 * 60 * 60))
        XCTAssertEqual(manager.result?.averagePrice ?? 0, 12.5, accuracy: 0.0001)
        XCTAssertFalse(manager.failedToFindResult)
    }

    func testCalculateCheapestHoursTrimsWindowForNonIntegerHourDuration() {
        let manager = CheapestHourManager()
        manager.startDate = Self.base
        manager.endDate = Self.base.addingTimeInterval(4 * 60 * 60)
        manager.timeOfUsage = Int(1.5 * 60 * 60) // 90 minutes
        let data = Self.energyData(prices: [30, 5, 10, 40])

        manager.calculateCheapestHours(energyData: data)

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in manager.result != nil || manager.failedToFindResult },
            object: nil
        )
        wait(for: [expectation], timeout: 2)

        // Cheapest 2-slot window is hours 1–2 (avg 7.5 cent).
        // Hour 1 (price 5) is cheaper than hour 2 (price 10),
        // so the 30-min remainder is trimmed from the end.
        XCTAssertEqual(manager.result?.startDate, Self.base.addingTimeInterval(60 * 60))
        XCTAssertEqual(manager.result?.endDate,   Self.base.addingTimeInterval(2.5 * 60 * 60))
        XCTAssertFalse(manager.failedToFindResult)
    }

    private static let base = Date(timeIntervalSince1970: 4_102_444_800)

    private static func energyData(prices: [Double]) -> EnergyData {
        let points = prices.enumerated().map { index, price in
            """
            {
              "start_timestamp": \(Int(base.timeIntervalSince1970) + index * 3600),
              "end_timestamp": \(Int(base.timeIntervalSince1970) + (index + 1) * 3600),
              "marketprice": \(price * 10)
            }
            """
        }.joined(separator: ",")
        var data = try! EnergyData.jsonDecoder().decode(
            EnergyData.self,
            from: Data(
                """
                {
                  "area": "DE-LU",
                  "resolution": "PT60M",
                  "prices": [\(points)]
                }
                """.utf8
            )
        )
        data.computeValues(
            with: PricingConfiguration(
                fixedPriceAddOn: 0,
                percentagePriceAddOn: 0,
                taxEnabled: true,
                orderedAddOns: [],
                marketArea: MarketArea(key: "TEST", displayName: "Test", countryCode: "DE", timezone: "Europe/Berlin", currency: "EUR", taxMultiplier: nil)
            )
        )
        return data
    }
}

import XCTest
@testable import AWattPrice

final class SettingsAndNotificationTests: XCTestCase {
    func testMonthlyFixedCostIsConvertedToCentPerKilowattHour() {
        let setting = Setting()
        setting.monthlyFixedCost = 10
        setting.annualConsumptionKWh = 2_400

        XCTAssertEqual(setting.monthlyFixedCostPrice, 5, accuracy: 0.0001)
        XCTAssertEqual(setting.totalPriceAddOn, 5, accuracy: 0.0001)
    }

    func testPriceAddOnOrderIsNormalizedAndFiltersZeroValues() {
        let setting = Setting()
        setting.baseFeePrice = 1.5
        setting.percentagePriceAddOn = 7
        setting.monthlyFixedCost = 12
        setting.annualConsumptionKWh = 3_600

        setting.orderedPriceAddOnKinds = [.monthly, .fixed, .monthly]

        XCTAssertEqual(setting.orderedPriceAddOnKinds, [.monthly, .fixed, .percentage])
        XCTAssertEqual(setting.orderedPriceAddOns.map(\.kind), [.monthly, .fixed, .percentage])
        XCTAssertEqual(setting.orderedPriceAddOns[0].value, 4, accuracy: 0.0001)
        XCTAssertEqual(setting.orderedPriceAddOns[1].value, 1.5, accuracy: 0.0001)
        XCTAssertEqual(setting.orderedPriceAddOns[2].value, 7, accuracy: 0.0001)
    }

    func testActiveNotificationRuleCountReflectsEnabledRules() {
        let setting = Setting()
        setting.priceDropsBelowEnabled = true
        setting.dailySummaryEnabled = true

        XCTAssertEqual(setting.activeNotificationRuleCount, 2)
    }

    func testNotificationConfigurationUsesTaxSetting() throws {
        let setting = Setting()
        setting.taxEnabled = false

        let configuration = NotificationConfiguration.create("token-1", setting)
        let payload = try JSONSerialization.jsonObject(with: JSONEncoder().encode(configuration)) as? [String: Any]
        let general = try XCTUnwrap(payload?["general"] as? [String: Any])

        XCTAssertEqual(general["tax"] as? Bool, false)
    }

    func testNotificationConfigurationEncodesThresholdsOnlyForEnabledRules() throws {
        let setting = Setting()
        setting.marketArea = .austria
        setting.baseFeePrice = 2
        setting.percentagePriceAddOn = 10
        setting.monthlyFixedCost = 12
        setting.annualConsumptionKWh = 2_400
        setting.orderedPriceAddOnKinds = [.fixed, .percentage, .monthly]
        setting.priceDropsBelowEnabled = true
        setting.priceDropsBelowThreshold = 15
        setting.priceRisesAboveEnabled = false
        setting.priceRisesAboveThreshold = 50
        setting.dailySummaryEnabled = true

        let configuration = NotificationConfiguration.create("token-1", setting)
        let payload = try JSONSerialization.jsonObject(with: JSONEncoder().encode(configuration)) as? [String: Any]
        let general = try XCTUnwrap(payload?["general"] as? [String: Any])
        let rules = try XCTUnwrap(payload?["rules"] as? [String: Any])
        let priceBelow = try XCTUnwrap(rules["price_below"] as? [String: Any])
        let priceAbove = try XCTUnwrap(rules["price_above"] as? [String: Any])
        let dailySummary = try XCTUnwrap(rules["daily_summary"] as? [String: Any])

        XCTAssertEqual(payload?["token"] as? String, "token-1")
        XCTAssertEqual(general["area"] as? String, "AT")
        XCTAssertEqual(general["tax"] as? Bool, true)
        XCTAssertEqual(general["base_fee"] as? Double, 8)
        XCTAssertEqual(general["fixed_add_on"] as? Double, 2)
        XCTAssertEqual(general["monthly_fixed_cost_add_on"] as? Double, 6)
        XCTAssertEqual(general["add_on_order"] as? [String], ["fixed", "percentage", "monthly"])
        XCTAssertEqual(priceBelow["active"] as? Bool, true)
        XCTAssertEqual(priceBelow["threshold"] as? Int, 15)
        XCTAssertEqual(priceAbove["active"] as? Bool, false)
        XCTAssertTrue(priceAbove.keys.contains("threshold"))
        XCTAssertTrue(priceAbove["threshold"] is NSNull)
        XCTAssertEqual(dailySummary["active"] as? Bool, true)
    }

    func testMonthlyFixedCostIsZeroWhenAnnualConsumptionIsZero() {
        let setting = Setting()
        setting.monthlyFixedCost = 10.0
        setting.annualConsumptionKWh = 0
        XCTAssertEqual(setting.monthlyFixedCostPrice, 0)
    }

    func testNotificationExampleResponseDefaultsMissingLocArgsToEmptyArray() throws {
        let response = try JSONDecoder().decode(
            NotificationExampleResponse.self,
            from: Data(
                """
                {
                  "would_send": false,
                  "title_loc_key": null,
                  "body_loc_key": null
                }
                """.utf8
            )
        )

        XCTAssertFalse(response.wouldSend)
        XCTAssertNil(response.titleLocKey)
        XCTAssertNil(response.bodyLocKey)
        XCTAssertEqual(response.locArgs, [])
    }
}

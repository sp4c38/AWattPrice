import XCTest
@testable import AWattPrice

final class APIClientTests: XCTestCase {
    func testEnergyDataRequestUsesMarketAreaEndpoint() {
        let request = APIClient.createEnergyDataRequest(marketArea: .germanyLuxembourg)

        XCTAssertEqual(request.urlRequest.url?.absoluteString, "https://api.awattprice.com/v3/prices/DE-LU")
        XCTAssertEqual(request.urlRequest.cachePolicy, .reloadIgnoringLocalAndRemoteCacheData)
        XCTAssertEqual(request.urlRequest.timeoutInterval, 90)
    }

    func testHistoryRequestFormatsDateInMarketAreaTimezone() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let instant = calendar.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 12))!
        let request = APIClient.createEnergyPriceHistoryRequest(marketArea: .germanyLuxembourg, date: instant)

        XCTAssertEqual(request.urlRequest.url?.absoluteString, "https://api.awattprice.com/v3/prices/DE-LU/history/2026-03-29")
    }

    func testGenerationMixRequestsUseExpectedEndpoints() {
        let history = APIClient.createGenerationMixHistoryRequest(marketArea: .austria)

        XCTAssertEqual(history.urlRequest.url?.absoluteString, "https://api.awattprice.com/v3/generation-mix/AT/published-history?hours=24")
    }

    func testGenerationMixHistoryRequestAlwaysUsesWeekRangeForGermanyLuxembourg() {
        let history = APIClient.createGenerationMixHistoryRequest(marketArea: .germanyLuxembourg)

        XCTAssertEqual(history.urlRequest.url?.absoluteString, "https://api.awattprice.com/v3/generation-mix/DE-LU/published-history?hours=168")
    }

    func testGenerationMixHistoryRequestSupportsWeekRange() {
        let history = APIClient.createGenerationMixHistoryRequest(marketArea: .austria, range: .week)

        XCTAssertEqual(history.urlRequest.url?.absoluteString, "https://api.awattprice.com/v3/generation-mix/AT/published-history?hours=168")
    }

    func testPriceStatisticsRequestPreservesPriceAddOnOrder() throws {
        let setting = Setting()
        setting.baseFeePrice = 3.5
        setting.percentagePriceAddOn = 12
        setting.priceAddOnOrder = "fixed,percentage,tax,monthly"
        let request = try APIClient.createPriceStatisticsRequest(
            marketArea: .germanyLuxembourg,
            body: PriceStatisticsRequestBody(pricingConfiguration: setting.pricingConfiguration)
        )
        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try XCTUnwrap(request.urlRequest.httpBody)) as? [String: Any]
        )
        let addOns = try XCTUnwrap(payload["add_ons"] as? [[String: Any]])

        XCTAssertEqual(request.urlRequest.url?.absoluteString, "https://api.awattprice.com/v3/prices/DE-LU/statistics")
        XCTAssertEqual(request.urlRequest.httpMethod, "POST")
        XCTAssertNil(payload["range"])
        XCTAssertEqual(addOns.compactMap { $0["kind"] as? String }, ["fixed", "percentage", "tax"])
    }

    func testPriceStatisticsResponseDecodesBackendContract() throws {
        let json = """
        {
          "1mo": {
          "average_price": 18.59,
          "comparison_change_percent": -7.8,
          "lowest": {"price": -3.72, "timestamp": 1786982400},
          "highest": {"price": 68.44, "timestamp": 1786035600},
          "negative_hours": 11.25,
          "below_average_percent": 58,
          "trend": [{"start_timestamp": 1786032000, "average_price": 24.1}],
          "weekday_hour_pattern": [{"weekday": 1, "hour": 0, "average_price": 22.4}],
          "highlight": {"kind": "weekday", "value": 7, "average_price": 19.8},
          "coverage": {"percent": 99.5, "is_complete": false, "is_usable": true}
          }
        }
        """

        let response = try PriceStatisticsData.jsonDecoder().decode(
            [String: PriceStatisticsData].self,
            from: Data(json.utf8)
        )
        let data = try XCTUnwrap(response["1mo"])

        XCTAssertEqual(data.averagePrice, 18.59)
        XCTAssertEqual(data.negativeHours, 11.25)
        XCTAssertEqual(data.trend.first?.averagePrice, 24.1)
        XCTAssertEqual(data.weekdayHourPattern.first?.weekday, 1)
        XCTAssertEqual(data.weekdayHourPattern.first?.hour, 0)
        XCTAssertEqual(data.weekdayHourPattern.first?.averagePrice, 22.4)
        XCTAssertEqual(data.highlight.value, 7)
        XCTAssertFalse(data.coverage.isComplete)
        XCTAssertTrue(data.coverage.isUsable)
    }

    func testNotificationRequestRequiresToken() throws {
        let setting = Setting()
        let missingToken = APIClient.createNotificationRequest(NotificationConfiguration.create(nil, setting))
        let request = try XCTUnwrap(APIClient.createNotificationRequest(NotificationConfiguration.create("token-1", setting)))

        XCTAssertNil(missingToken)
        XCTAssertEqual(request.urlRequest.url?.absoluteString, "https://api.awattprice.com/v3/notifications/device/")
        XCTAssertEqual(request.urlRequest.httpMethod, "PUT")
        XCTAssertEqual(request.urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNotNil(request.urlRequest.httpBody)
    }

    func testNotificationExampleRequestCreatesPlaceholderToken() throws {
        let request = try XCTUnwrap(
            APIClient.createNotificationExampleRequest(
                ruleType: .priceBelow,
                notificationConfiguration: NotificationConfiguration.create(nil, Setting())
            )
        )
        let payload = try JSONSerialization.jsonObject(with: try XCTUnwrap(request.urlRequest.httpBody)) as? [String: Any]

        XCTAssertEqual(request.urlRequest.url?.absoluteString, "https://api.awattprice.com/v3/notifications/examples/price_below/")
        XCTAssertEqual(request.urlRequest.httpMethod, "POST")
        XCTAssertEqual(payload?["force"] as? Bool, true)
        XCTAssertEqual(payload?["token"] as? String, "example")
    }
}

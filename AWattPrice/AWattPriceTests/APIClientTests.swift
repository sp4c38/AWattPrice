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

        XCTAssertEqual(history.urlRequest.url?.absoluteString, "https://api.awattprice.com/v3/generation-mix/AT/history?hours=24")
    }

    func testGenerationMixHistoryRequestAlwaysUsesWeekRangeForGermanyLuxembourg() {
        let history = APIClient.createGenerationMixHistoryRequest(marketArea: .germanyLuxembourg)

        XCTAssertEqual(history.urlRequest.url?.absoluteString, "https://api.awattprice.com/v3/generation-mix/DE-LU/history?hours=168")
    }

    func testGenerationMixHistoryRequestSupportsWeekRange() {
        let history = APIClient.createGenerationMixHistoryRequest(marketArea: .austria, range: .week)

        XCTAssertEqual(history.urlRequest.url?.absoluteString, "https://api.awattprice.com/v3/generation-mix/AT/history?hours=168")
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

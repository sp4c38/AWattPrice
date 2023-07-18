//
//  UITesting.swift
//  UITesting
//
//  Created by Léon Becker on 17.07.23.
//

import XCTest

final class UITesting: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        snapshot("00MainScreen")
        app.tabBars.firstMatch.buttons.element(boundBy: 0).tap()
        if UIDevice.current.userInterfaceIdiom == .pad {
            app.navigationBars["_TtGC7SwiftUI19UIHosting"].buttons["ToggleSidebar"].tap()
        }
        snapshot("02Setting")
        app.tabBars.firstMatch.buttons.element(boundBy: 2).tap()
        snapshot("01CheapestPrice")
        
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

//    func testLaunchPerformance() throws {
//        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
//            // This measures how long it takes to launch your application.
//            measure(metrics: [XCTApplicationLaunchMetric()]) {
//                XCUIApplication().launch()
//            }
//        }
//    }
}

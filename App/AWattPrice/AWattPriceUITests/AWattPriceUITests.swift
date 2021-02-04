//
//  AWattPriceUITests.swift
//  AWattPriceUITests
//
//  Created by Léon Becker on 02.02.21.
//

import XCTest

class AWattPriceTestManager {
    let app: XCUIApplication
    
    var staticTexts: XCUIElementQuery?
    var buttons: XCUIElementQuery?
    
    init(_ app: XCUIApplication) {
        self.app = app
    }
    
    func getStaticTexts() {
        staticTexts = app.staticTexts
    }
    
    func getButtons() {
        buttons = app.buttons
    }
}

extension AWattPriceTestManager {
    func testHelpView() {
        guard let texts = self.staticTexts else { return }
        let goToHelpButton = texts["Help & Suggestions"]
        XCTAssertTrue(goToHelpButton.exists)
        goToHelpButton.tap()
    }
}

class AWattPriceUITests: XCTestCase {
    let manager = AWattPriceTestManager(XCUIApplication())
    
    override func setUp() {
        manager.app.launch()
        manager.getStaticTexts()
        manager.getButtons()
    }
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testSettings() {
        guard let staticTexts = manager.staticTexts else { return }
        
        let app = manager.app
        
        let settingsTab = staticTexts["Settings"]
        XCTAssertTrue(settingsTab.exists)
        settingsTab.tap()

        let regionGermany = app.buttons["🇩🇪 Germany"]
        let regionAustria = app.buttons["🇦🇹 Austria"]
        XCTAssertTrue(regionGermany.exists)
        XCTAssertTrue(regionAustria.exists)
        regionAustria.tap()
        regionGermany.tap()
        
        manager.testHelpView()
    }

//    func testLaunchPerformance() throws {
//        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, *) {
//            // This measures how long it takes to launch your application.
//            measure(metrics: [XCTApplicationLaunchMetric()]) {
//                XCUIApplication().launch()
//            }
//        }
//    }
}

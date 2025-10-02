import XCTest
import OSLog
import Foundation
@testable import SkipFuseRevenueCat

let logger: Logger = Logger(subsystem: "SkipFuseRevenueCat", category: "Tests")

@available(macOS 13, *)
final class SkipFuseRevenueCatTests: XCTestCase {

    func testSkipFuseRevenueCat() throws {
        logger.log("running testSkipFuseRevenueCat")
        XCTAssertEqual(1 + 2, 3, "basic test")
    }

    func testDecodeType() throws {
        // load the TestData.json file from the Resources folder and decode it into a struct
        let resourceURL: URL = try XCTUnwrap(Bundle.module.url(forResource: "TestData", withExtension: "json"))
        let testData = try JSONDecoder().decode(TestData.self, from: Data(contentsOf: resourceURL))
        XCTAssertEqual("SkipFuseRevenueCat", testData.testModuleName)
    }

}

struct TestData : Codable, Hashable {
    var testModuleName: String
}

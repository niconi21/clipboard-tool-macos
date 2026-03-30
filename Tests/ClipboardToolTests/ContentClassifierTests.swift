import XCTest
@testable import ClipboardTool

final class ContentClassifierTests: XCTestCase {
    private let classifier = ContentClassifier()

    func testURL() {
        XCTAssertEqual(classifier.classify("https://github.com"), .url)
    }

    func testEmail() {
        XCTAssertEqual(classifier.classify("user@example.com"), .email)
    }

    func testPlainText() {
        XCTAssertEqual(classifier.classify("Hello world"), .text)
    }
}

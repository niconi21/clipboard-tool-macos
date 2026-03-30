import XCTest
@testable import ClipboardTool

final class ContentClassifierTests: XCTestCase {
    private let classifier = ContentClassifier()

    // MARK: - URL

    func testURL_schemeFull() {
        XCTAssertEqual(classifier.classify("https://www.example.com"), .url)
    }

    func testURL_schemeWithPath() {
        XCTAssertEqual(classifier.classify("https://github.com/niconi21/clipboard-tool"), .url)
    }

    func testURL_httpScheme() {
        XCTAssertEqual(classifier.classify("http://example.com"), .url)
    }

    func testURL_ftpScheme() {
        XCTAssertEqual(classifier.classify("ftp://files.example.com/file.zip"), .url)
    }

    func testURL_bareDomain() {
        XCTAssertEqual(classifier.classify("github.com/foo"), .url)
    }

    func testURL_wwwBareDomain() {
        XCTAssertEqual(classifier.classify("www.example.org"), .url)
    }

    // MARK: - Email

    func testEmail_simple() {
        XCTAssertEqual(classifier.classify("user@example.com"), .email)
    }

    func testEmail_withPlusTag() {
        XCTAssertEqual(classifier.classify("user+tag@mail.co.uk"), .email)
    }

    func testEmail_invalid_missingAt() {
        XCTAssertNotEqual(classifier.classify("notanemail.com"), .email)
    }

    func testEmail_invalid_missingTLD() {
        XCTAssertNotEqual(classifier.classify("user@nodot"), .email)
    }

    // MARK: - Phone

    func testPhone_e164() {
        XCTAssertEqual(classifier.classify("+12025551234"), .phone)
    }

    func testPhone_formatted() {
        XCTAssertEqual(classifier.classify("(123) 456-7890"), .phone)
    }

    func testPhone_dashes() {
        XCTAssertEqual(classifier.classify("123-456-7890"), .phone)
    }

    // MARK: - Color

    func testColor_threeDigitHex() {
        XCTAssertEqual(classifier.classify("#fff"), .color)
    }

    func testColor_sixDigitHex() {
        XCTAssertEqual(classifier.classify("#1a2b3c"), .color)
    }

    func testColor_eightDigitHex_withAlpha() {
        XCTAssertEqual(classifier.classify("#ff0000ff"), .color)
    }

    func testColor_uppercase() {
        XCTAssertEqual(classifier.classify("#AABBCC"), .color)
    }

    func testColor_invalid_missingHash() {
        XCTAssertNotEqual(classifier.classify("1a2b3c"), .color)
    }

    func testColor_invalid_wrongLength() {
        XCTAssertNotEqual(classifier.classify("#12345"), .color)
    }

    // MARK: - Code

    func testCode_swiftSnippet() {
        let snippet = """
        func greet(name: String) -> String {
            return "Hello, \\(name)"
        }
        """
        XCTAssertEqual(classifier.classify(snippet), .code)
    }

    func testCode_pythonSnippet() {
        let snippet = "def foo():\n    return 42"
        XCTAssertEqual(classifier.classify(snippet), .code)
    }

    func testCode_importStatement() {
        // "import " + "let " = 2 markers
        let snippet = "import Foundation\nlet x = 1"
        XCTAssertEqual(classifier.classify(snippet), .code)
    }

    func testCode_consistentIndentation() {
        let snippet = "function foo() {\n    line1\n    line2\n    line3\n}"
        XCTAssertEqual(classifier.classify(snippet), .code)
    }

    // MARK: - Text (fallback)

    func testPlainText_sentence() {
        XCTAssertEqual(classifier.classify("Hello world"), .text)
    }

    func testPlainText_emptyString() {
        XCTAssertEqual(classifier.classify(""), .text)
    }

    func testPlainText_whitespaceOnly() {
        XCTAssertEqual(classifier.classify("   "), .text)
    }

    func testPlainText_singleWord() {
        XCTAssertEqual(classifier.classify("clipboard"), .text)
    }
}

import AppKit
import XCTest
@testable import ClipboardTool

final class ImageStoreTests: XCTestCase {

    // MARK: - Helpers

    /// Creates an ImageStore backed by a fresh temporary directory that is
    /// deleted after each test.
    private var tempDir: URL!
    private var store: ImageStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        store = ImageStore(imagesDir: tempDir)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        try super.tearDownWithError()
    }

    /// Returns a 2×2 red NSImage suitable for testing without requiring AppKit
    /// resources on disk.
    private func makeRedImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: NSSize(width: 2, height: 2)).fill()
        image.unlockFocus()
        return image
    }

    /// Returns a 2×2 blue NSImage (different pixel data from makeRedImage).
    private func makeBlueImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(origin: .zero, size: NSSize(width: 2, height: 2)).fill()
        image.unlockFocus()
        return image
    }

    // MARK: - Tests: store(image:)

    func testStore_returnsRelativePath() throws {
        let path = try store.store(image: makeRedImage())
        XCTAssertNotNil(path, "Storing a new image must return a relative path.")
        XCTAssertTrue(path?.hasPrefix("images/") == true, "Relative path must start with 'images/'.")
        XCTAssertTrue(path?.hasSuffix(".png") == true, "Relative path must end with '.png'.")
    }

    func testStore_writesFullSizeFile() throws {
        let path = try store.store(image: makeRedImage())
        XCTAssertNotNil(path)
        let filename = URL(fileURLWithPath: path!).lastPathComponent
        let fileURL = tempDir.appendingPathComponent(filename)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: fileURL.path),
            "Full-size PNG must exist on disk after store."
        )
    }

    func testStore_dedup_returnNilForSameImage() throws {
        let firstPath = try store.store(image: makeRedImage())
        XCTAssertNotNil(firstPath, "First store must succeed.")

        let secondPath = try store.store(image: makeRedImage())
        XCTAssertNil(secondPath, "Second store of the same image must return nil (dedup).")
    }

    func testStore_differentImages_returnDifferentPaths() throws {
        let redPath = try store.store(image: makeRedImage())
        let bluePath = try store.store(image: makeBlueImage())
        XCTAssertNotNil(redPath)
        XCTAssertNotNil(bluePath)
        XCTAssertNotEqual(redPath, bluePath, "Different images must produce different paths.")
    }

    // MARK: - Tests: thumbnail creation

    func testStore_createsThumbnailFile() throws {
        let path = try store.store(image: makeRedImage())
        XCTAssertNotNil(path)
        let thumbURL = store.thumbnailURL(for: path!)
        XCTAssertNotNil(thumbURL, "thumbnailURL must resolve for a valid image path.")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: thumbURL!.path),
            "Thumbnail PNG must exist on disk after store."
        )
    }

    func testStore_thumbnailFilenameContainsThumbSuffix() throws {
        let path = try store.store(image: makeRedImage())
        XCTAssertNotNil(path)
        let thumbURL = store.thumbnailURL(for: path!)
        XCTAssertTrue(
            thumbURL?.lastPathComponent.hasSuffix("_thumb.png") == true,
            "Thumbnail filename must end with '_thumb.png'."
        )
    }

    // MARK: - Tests: thumbnailURL and fullImageURL

    func testThumbnailURL_invalidPath_returnsNil() {
        XCTAssertNil(store.thumbnailURL(for: "text/something.txt"))
        XCTAssertNil(store.thumbnailURL(for: ""))
        XCTAssertNil(store.thumbnailURL(for: "images/nopng"))
    }

    func testFullImageURL_returnsURLForValidPath() throws {
        let path = try store.store(image: makeRedImage())
        XCTAssertNotNil(path)
        let url = store.fullImageURL(for: path!)
        XCTAssertNotNil(url, "fullImageURL must resolve for a valid image path.")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: url!.path),
            "Full-size file must exist at the returned URL."
        )
    }

    func testFullImageURL_invalidPath_returnsNil() {
        XCTAssertNil(store.fullImageURL(for: "text/foo.txt"))
        XCTAssertNil(store.fullImageURL(for: ""))
    }

    // MARK: - Tests: cleanupOrphaned

    func testCleanupOrphaned_deletesUnreferencedFiles() throws {
        let path = try store.store(image: makeRedImage())
        XCTAssertNotNil(path)

        // Pass an empty set — the stored file is unreferenced.
        try store.cleanupOrphaned(referencedPaths: [])

        let fullURL = store.fullImageURL(for: path!)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: fullURL?.path ?? ""),
            "Unreferenced full-size file must be deleted."
        )
        let thumbURL = store.thumbnailURL(for: path!)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: thumbURL?.path ?? ""),
            "Unreferenced thumbnail must be deleted."
        )
    }

    func testCleanupOrphaned_keepsReferencedFiles() throws {
        let path = try store.store(image: makeRedImage())
        XCTAssertNotNil(path)

        // Pass the path as referenced — nothing should be deleted.
        try store.cleanupOrphaned(referencedPaths: [path!])

        let fullURL = store.fullImageURL(for: path!)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: fullURL?.path ?? ""),
            "Referenced full-size file must not be deleted."
        )
        let thumbURL = store.thumbnailURL(for: path!)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: thumbURL?.path ?? ""),
            "Referenced thumbnail must not be deleted."
        )
    }

    func testCleanupOrphaned_onlyDeletesUnreferenced() throws {
        let redPath = try store.store(image: makeRedImage())
        let bluePath = try store.store(image: makeBlueImage())
        XCTAssertNotNil(redPath)
        XCTAssertNotNil(bluePath)

        // Keep red, delete blue.
        try store.cleanupOrphaned(referencedPaths: [redPath!])

        let redURL = store.fullImageURL(for: redPath!)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: redURL?.path ?? ""),
            "Referenced red image must survive cleanup."
        )

        let blueURL = store.fullImageURL(for: bluePath!)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: blueURL?.path ?? ""),
            "Unreferenced blue image must be deleted."
        )
    }
}

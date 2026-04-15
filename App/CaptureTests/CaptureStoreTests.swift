import XCTest
@testable import Capture

@MainActor
final class CaptureStoreTests: XCTestCase {
    var mock: MockFileStore!
    var store: CaptureStore!

    override func setUp() async throws {
        try await super.setUp()
        mock = MockFileStore()
        store = CaptureStore(fileStore: mock)
        await store.resolveContainer()
    }

    // MARK: - createCapture

    func test_createCapture_writesMarkdownFile() throws {
        try store.createCapture(title: "Hello", body: "World")

        let mdFile = mock.files.keys.first { $0.hasSuffix(".md") }
        XCTAssertNotNil(mdFile, "Expected a .md file to be written")
    }

    func test_createCapture_markdownContainsTitleAndBody() throws {
        try store.createCapture(title: "My Idea", body: "It's great")

        let mdPath = try XCTUnwrap(mock.files.keys.first { $0.hasSuffix(".md") })
        let content = String(data: mock.files[mdPath]!, encoding: .utf8)!
        XCTAssertTrue(content.contains("# My Idea"))
        XCTAssertTrue(content.contains("It's great"))
    }

    func test_createCapture_writesShopfloorMetadataFile() throws {
        try store.createCapture(title: "Test", body: "Body")

        let jsonFile = mock.files.keys.first { $0.contains(".shopfloor/files") && $0.hasSuffix(".json") }
        XCTAssertNotNil(jsonFile, "Expected a .shopfloor/files/[UUID].json to be written")
    }

    func test_createCapture_metadataUUIDMatchesFilename() throws {
        try store.createCapture(title: "Check UUID", body: "")

        let jsonPath = try XCTUnwrap(mock.files.keys.first { $0.contains(".shopfloor/files") && $0.hasSuffix(".json") })
        let data = try XCTUnwrap(mock.files[jsonPath])
        let metadata = try JSONDecoder().decode(CaptureMetadata.self, from: data)

        // The JSON file should be named [UUID].json
        XCTAssertTrue(jsonPath.hasSuffix("\(metadata.uuid).json"), "Metadata filename must match UUID field")
    }

    func test_createCapture_captureMethodIsDirect() throws {
        try store.createCapture(title: "Direct", body: "")

        let jsonPath = try XCTUnwrap(mock.files.keys.first { $0.contains(".shopfloor/files") && $0.hasSuffix(".json") })
        let metadata = try JSONDecoder().decode(CaptureMetadata.self, from: mock.files[jsonPath]!)
        XCTAssertEqual(metadata.captureMethod, "direct")
    }

    func test_createCapture_writesToInboxByDefault() throws {
        try store.createCapture(title: "Inbox Test", body: "")

        let mdPath = try XCTUnwrap(mock.files.keys.first { $0.hasSuffix(".md") })
        XCTAssertTrue(mdPath.contains("/Inbox/"), "Capture without explicit notebook should land in Inbox")
    }

    func test_createCapture_writesToSpecifiedNotebook() throws {
        let root = try XCTUnwrap(store.rootURL)
        let target = root.appendingPathComponent("Research", isDirectory: true)
        try store.createCapture(title: "Research Note", body: "", notebook: target)

        let mdPath = try XCTUnwrap(mock.files.keys.first { $0.hasSuffix(".md") })
        XCTAssertTrue(mdPath.contains("/Research/"), "Capture should land in the specified notebook")
    }

    // MARK: - createNotebook

    func test_createNotebook_createsDirectory() throws {
        try store.createNotebook(name: "Projects")

        XCTAssertTrue(mock.directories.contains { $0.hasSuffix("/Projects") })
    }

    func test_createNotebook_createsNestedDirectory() throws {
        let root = try XCTUnwrap(store.rootURL)
        let parent = root.appendingPathComponent("Work", isDirectory: true)
        mock.directories.append(parent.path) // simulate Work already existing

        try store.createNotebook(name: "Sprint", parent: parent)

        XCTAssertTrue(mock.directories.contains { $0.hasSuffix("/Work/Sprint") })
    }

    // MARK: - CaptureMetadata

    func test_captureMetadata_encodesAndDecodesRoundtrip() throws {
        let meta = CaptureMetadata.make(filename: "test.md", notebookPath: "/Inbox")
        let data = try JSONEncoder().encode(meta)
        let decoded = try JSONDecoder().decode(CaptureMetadata.self, from: data)

        XCTAssertEqual(meta.uuid, decoded.uuid)
        XCTAssertEqual(meta.filename, decoded.filename)
        XCTAssertEqual(meta.captureMethod, decoded.captureMethod)
        XCTAssertEqual(meta.notebookPath, decoded.notebookPath)
    }

    // MARK: - No container

    func test_createCapture_throwsWhenNoContainer() {
        // rootURL is nil by default (resolved async via resolveContainer()).
        // A store with no container just never has rootURL set.
        let noContainerStore = CaptureStore(fileStore: MockFileStore())
        // rootURL is nil — store was never resolved
        XCTAssertThrowsError(try noContainerStore.createCapture(title: "X", body: "")) { error in
            XCTAssertTrue(error is CaptureError)
        }
    }
}

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

    override func tearDown() async throws {
        store = nil
        mock = nil
        try await super.tearDown()
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
        let noContainerStore = CaptureStore(fileStore: MockFileStore())
        XCTAssertThrowsError(try noContainerStore.createCapture(title: "X", body: "")) { error in
            if let captureError = error as? CaptureError, case .noContainer = captureError { }
            else { XCTFail("Expected CaptureError.noContainer, got \(error)") }
        }
    }

    // MARK: - contentType (Sprint 2)

    func test_createCapture_setsContentTypeText() throws {
        try store.createCapture(title: "My Story", body: "")

        let jsonPath = try XCTUnwrap(mock.files.keys.first { $0.contains(".shopfloor/files") && $0.hasSuffix(".json") })
        let meta = try JSONDecoder().decode(CaptureMetadata.self, from: mock.files[jsonPath]!)
        XCTAssertEqual(meta.contentType, "text", "A .md capture must have contentType = 'text'")
    }

    func test_createCapture_setsContentTypeLinkForShareSheetWithURL() throws {
        try store.createCapture(
            title: "cool article",
            body: "",
            sourceURL: "https://example.com/article",
            captureMethod: "share_sheet"
        )

        let jsonPath = try XCTUnwrap(mock.files.keys.first { $0.contains(".shopfloor/files") && $0.hasSuffix(".json") })
        let meta = try JSONDecoder().decode(CaptureMetadata.self, from: mock.files[jsonPath]!)
        XCTAssertEqual(meta.contentType, "link",
            "share_sheet + non-empty sourceURL must resolve to contentType 'link', not 'text' or 'other'")
    }

    func test_createCapture_shareSheetWithEmptyURLFallsBackToText() throws {
        try store.createCapture(
            title: "empty url capture",
            body: "",
            sourceURL: "",
            captureMethod: "share_sheet"
        )

        let jsonPath = try XCTUnwrap(mock.files.keys.first { $0.contains(".shopfloor/files") && $0.hasSuffix(".json") })
        let meta = try JSONDecoder().decode(CaptureMetadata.self, from: mock.files[jsonPath]!)
        XCTAssertEqual(meta.contentType, "text",
            "share_sheet + empty sourceURL must fall back to filename-based contentType ('text' for .md)")
    }

    func test_createCapture_shareSheetWithNilURLFallsBackToText() throws {
        try store.createCapture(
            title: "nil url capture",
            body: "",
            sourceURL: nil,
            captureMethod: "share_sheet"
        )

        let jsonPath = try XCTUnwrap(mock.files.keys.first { $0.contains(".shopfloor/files") && $0.hasSuffix(".json") })
        let meta = try JSONDecoder().decode(CaptureMetadata.self, from: mock.files[jsonPath]!)
        XCTAssertEqual(meta.contentType, "text",
            "share_sheet + nil sourceURL must fall back to filename-based contentType ('text' for .md)")
    }

    // MARK: - captureNote (Sprint 2)

    func test_createCapture_captureNoteNilByDefault() throws {
        try store.createCapture(title: "No Note", body: "")

        let jsonPath = try XCTUnwrap(mock.files.keys.first { $0.contains(".shopfloor/files") && $0.hasSuffix(".json") })
        let jsonString = try XCTUnwrap(String(data: mock.files[jsonPath]!, encoding: .utf8))
        // The key must be absent from JSON entirely when nil (not written as null).
        XCTAssertFalse(jsonString.contains("captureNote"),
            "captureNote key must be absent from JSON when not provided")
    }

    func test_createCapture_captureNotePersisted() throws {
        try store.createCapture(title: "With Note", body: "", captureNote: "For chapter 3")

        let jsonPath = try XCTUnwrap(mock.files.keys.first { $0.contains(".shopfloor/files") && $0.hasSuffix(".json") })
        let meta = try JSONDecoder().decode(CaptureMetadata.self, from: mock.files[jsonPath]!)
        XCTAssertEqual(meta.captureNote, "For chapter 3")
    }

    // MARK: - captureNote (Sprint 2)

    func test_captureNote_returnsNoteFromStoredMetadata() throws {
        try store.createCapture(title: "Note Getter", body: "", captureNote: "retrieved note")
        let mdPath = try XCTUnwrap(mock.files.keys.first { $0.hasSuffix(".md") })
        let filename = URL(fileURLWithPath: mdPath).lastPathComponent

        let result = store.captureNote(forFilename: filename)
        XCTAssertEqual(result, "retrieved note",
            "captureNote(forFilename:) must return the stored captureNote via injected fileStore")
    }

    func test_captureNote_returnsNilWhenNotInIndex() {
        // No createCapture called — index is empty
        let result = store.captureNote(forFilename: "not-in-index.md")
        XCTAssertNil(result, "captureNote must return nil when filename is not in the index")
    }

    // MARK: - updateNote (Sprint 2)

    func test_updateNote_writesUpdatedMetadata() async throws {
        try store.createCapture(title: "Note Test", body: "")
        let filename = try XCTUnwrap(mock.files.keys.first { $0.hasSuffix(".md") }.map { URL(fileURLWithPath: $0).lastPathComponent })

        try await store.updateNote("new note here", forFilename: filename)

        let jsonPath = try XCTUnwrap(mock.files.keys.first { $0.contains(".shopfloor/files") && $0.hasSuffix(".json") })
        let meta = try JSONDecoder().decode(CaptureMetadata.self, from: mock.files[jsonPath]!)
        XCTAssertEqual(meta.captureNote, "new note here")
    }

    func test_updateNote_allowsNilToRemoveNote() async throws {
        try store.createCapture(title: "Has Note", body: "", captureNote: "initial note")
        let filename = try XCTUnwrap(mock.files.keys.first { $0.hasSuffix(".md") }.map { URL(fileURLWithPath: $0).lastPathComponent })

        try await store.updateNote(nil, forFilename: filename)

        let jsonPath = try XCTUnwrap(mock.files.keys.first { $0.contains(".shopfloor/files") && $0.hasSuffix(".json") })
        let jsonString = try XCTUnwrap(String(data: mock.files[jsonPath]!, encoding: .utf8))
        XCTAssertFalse(jsonString.contains("captureNote"),
            "captureNote key must be absent after updateNote(nil)")
    }

    func test_updateNote_treatsEmptyStringAsNil() async throws {
        try store.createCapture(title: "Empty Note", body: "", captureNote: "some text")
        let filename = try XCTUnwrap(mock.files.keys.first { $0.hasSuffix(".md") }.map { URL(fileURLWithPath: $0).lastPathComponent })

        try await store.updateNote("", forFilename: filename)

        let jsonPath = try XCTUnwrap(mock.files.keys.first { $0.contains(".shopfloor/files") && $0.hasSuffix(".json") })
        let jsonString = try XCTUnwrap(String(data: mock.files[jsonPath]!, encoding: .utf8))
        XCTAssertFalse(jsonString.contains("captureNote"),
            "Empty string must be treated as nil: captureNote key must be absent")
    }

    func test_updateNote_throwsUUIDNotFoundWhenNotInIndex() async {
        // Index is empty — no createCapture called, no warmIndex
        do {
            try await store.updateNote("some note", forFilename: "not-in-index-12345.md")
            XCTFail("Expected CaptureError.uuidNotFound to be thrown")
        } catch let error as CaptureError {
            if case .uuidNotFound(let filename) = error {
                XCTAssertEqual(filename, "not-in-index-12345.md")
            } else {
                XCTFail("Expected .uuidNotFound, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - deleteCapture (Sprint 2)

    func test_deleteCapture_removesMdFile() async throws {
        try store.createCapture(title: "To Delete", body: "")
        let mdPath = try XCTUnwrap(mock.files.keys.first { $0.hasSuffix(".md") })
        let mdURL = URL(fileURLWithPath: mdPath)

        try await store.deleteCapture(at: mdURL)

        XCTAssertNil(mock.files[mdPath], ".md file must be gone after deleteCapture")
    }

    func test_deleteCapture_removesShopfloorJSON() async throws {
        try store.createCapture(title: "To Delete JSON", body: "")
        let mdPath = try XCTUnwrap(mock.files.keys.first { $0.hasSuffix(".md") })
        let jsonPath = try XCTUnwrap(mock.files.keys.first { $0.contains(".shopfloor/files") && $0.hasSuffix(".json") })
        let mdURL = URL(fileURLWithPath: mdPath)

        try await store.deleteCapture(at: mdURL)

        XCTAssertNil(mock.files[jsonPath], ".json record must be gone after deleteCapture")
    }

    func test_deleteCapture_updatesFilenameToUUIDIndex() async throws {
        try store.createCapture(title: "Index Remove", body: "")
        let mdPath = try XCTUnwrap(mock.files.keys.first { $0.hasSuffix(".md") })
        let filename = URL(fileURLWithPath: mdPath).lastPathComponent
        let mdURL = URL(fileURLWithPath: mdPath)

        XCTAssertNotNil(store.filenameToUUID[filename], "Index must be populated after createCapture")

        try await store.deleteCapture(at: mdURL)

        XCTAssertNil(store.filenameToUUID[filename], "Index entry must be removed after deleteCapture")
    }

    func test_deleteCapture_throwsWhenNoContainer() async {
        let noContainerStore = CaptureStore(fileStore: MockFileStore())
        let fakeURL = URL(fileURLWithPath: "/nonexistent/capture.md")
        do {
            try await noContainerStore.deleteCapture(at: fakeURL)
            XCTFail("Expected CaptureError.noContainer to be thrown")
        } catch let error as CaptureError {
            if case .noContainer = error { } else {
                XCTFail("Expected .noContainer, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_deleteCapture_JSONSidecarOrphansWhenIndexNotWarmed() async throws {
        // Simulate a capture created in a prior session: .md and .json exist on disk
        // but filenameToUUID was never warmed in this session.
        let base = try XCTUnwrap(store.rootURL)
        let inboxURL = base.appendingPathComponent("Inbox", isDirectory: true)
        let shopfloorURL = base.deletingLastPathComponent()
            .appendingPathComponent(".shopfloor/files", isDirectory: true)

        let meta = CaptureMetadata.make(filename: "old-capture-1234.md", notebookPath: inboxURL.path)
        let jsonData = try JSONEncoder().encode(meta)
        let mdPath = inboxURL.appendingPathComponent("old-capture-1234.md").path
        let jsonPath = shopfloorURL.appendingPathComponent("\(meta.uuid).json").path
        mock.files[mdPath] = "# Old Capture".data(using: .utf8)
        mock.files[jsonPath] = jsonData
        // Do NOT call createCapture or contents(of:) — index stays empty

        let mdURL = URL(fileURLWithPath: mdPath)
        try await store.deleteCapture(at: mdURL)

        // .md is gone
        XCTAssertNil(mock.files[mdPath], ".md file must be deleted")
        // .json sidecar persists — rebuild() is the recovery path (by design)
        XCTAssertNotNil(mock.files[jsonPath],
            "When index is not warmed, .json sidecar is not deleted by deleteCapture. rebuild() cleans it up.")
    }

    func test_deleteCapture_missingJSONIsGraceful() async throws {
        try store.createCapture(title: "Missing JSON", body: "")
        let mdPath = try XCTUnwrap(mock.files.keys.first { $0.hasSuffix(".md") })
        let jsonPath = try XCTUnwrap(mock.files.keys.first { $0.contains(".shopfloor/files") && $0.hasSuffix(".json") })
        let mdURL = URL(fileURLWithPath: mdPath)

        // Simulate externally-deleted .json
        mock.files.removeValue(forKey: jsonPath)

        // deleteCapture must NOT throw even though .json is already gone
        try await store.deleteCapture(at: mdURL)
    }

    // MARK: - rebuild() (Sprint 2)

    func test_rebuild_removesOrphanJSON() async throws {
        let base = try XCTUnwrap(store.rootURL)
        let shopfloorURL = base.deletingLastPathComponent()
            .appendingPathComponent(".shopfloor/files", isDirectory: true)

        // Write an orphan .json with no matching .md file
        let orphanMeta = CaptureMetadata.make(filename: "ghost.md", notebookPath: base.appendingPathComponent("Inbox").path)
        let jsonData = try JSONEncoder().encode(orphanMeta)
        mock.files[shopfloorURL.appendingPathComponent("\(orphanMeta.uuid).json").path] = jsonData

        await store.rebuild()

        XCTAssertNil(mock.files[shopfloorURL.appendingPathComponent("\(orphanMeta.uuid).json").path],
            "Orphan .json must be removed by rebuild()")
        XCTAssertEqual(store.lastRebuildResult?.orphansRemoved, 1,
            "lastRebuildResult must report exactly 1 orphan removed")
    }

    func test_rebuild_keepsValidJSON() async throws {
        try store.createCapture(title: "Keep This", body: "")
        let jsonPath = try XCTUnwrap(mock.files.keys.first { $0.contains(".shopfloor/files") && $0.hasSuffix(".json") })

        await store.rebuild()

        XCTAssertNotNil(mock.files[jsonPath], "Valid .json with matching .md must survive rebuild()")
    }

    func test_rebuild_skipsICloudStubs() async throws {
        let base = try XCTUnwrap(store.rootURL)
        let inboxURL = base.appendingPathComponent("Inbox", isDirectory: true)
        let shopfloorURL = base.deletingLastPathComponent()
            .appendingPathComponent(".shopfloor/files", isDirectory: true)

        let meta = CaptureMetadata.make(filename: "stub.md", notebookPath: inboxURL.path)
        let jsonData = try JSONEncoder().encode(meta)
        let jsonPath = shopfloorURL.appendingPathComponent("\(meta.uuid).json").path
        let mdPath = inboxURL.appendingPathComponent("stub.md").path
        mock.files[jsonPath] = jsonData
        // Do NOT add mdPath to mock.files — simulate file absent from local disk
        // (the iCloud stub hasn't been downloaded yet)
        mock.stubbedDownloadStatus[mdPath] = .notDownloaded

        await store.rebuild()

        XCTAssertNotNil(mock.files[jsonPath],
            ".json for a not-yet-downloaded iCloud stub must NOT be removed by rebuild()")
    }

    func test_rebuild_updatesFilenameToUUIDIndex() async throws {
        try store.createCapture(title: "Will Be Deleted", body: "")
        let mdPath = try XCTUnwrap(mock.files.keys.first { $0.hasSuffix(".md") })
        let filename = URL(fileURLWithPath: mdPath).lastPathComponent

        XCTAssertNotNil(store.filenameToUUID[filename])

        // Simulate external deletion of the .md
        mock.files.removeValue(forKey: mdPath)

        await store.rebuild()

        XCTAssertNil(store.filenameToUUID[filename],
            "Index must be cleaned for orphaned filenames after rebuild()")
    }

    func test_rebuild_setsLastRebuildResult() async throws {
        let base = try XCTUnwrap(store.rootURL)
        let shopfloorURL = base.deletingLastPathComponent()
            .appendingPathComponent(".shopfloor/files", isDirectory: true)

        // Write 2 orphan .json files (no matching .md for either)
        for i in 1...2 {
            let meta = CaptureMetadata.make(
                filename: "orphan-\(i).md",
                notebookPath: base.appendingPathComponent("Inbox").path
            )
            let data = try JSONEncoder().encode(meta)
            mock.files[shopfloorURL.appendingPathComponent("\(meta.uuid).json").path] = data
        }

        await store.rebuild()

        XCTAssertEqual(store.lastRebuildResult?.orphansRemoved, 2,
            "lastRebuildResult must report both orphans removed")
    }

    func test_rebuild_silentlyReturnsWhenNoContainer() async {
        let noContainerStore = CaptureStore(fileStore: MockFileStore())
        // rootURL is nil — resolveContainer never called

        await noContainerStore.rebuild()

        XCTAssertNil(noContainerStore.lastRebuildResult,
            "lastRebuildResult must remain nil when no container is available")
    }

    func test_rebuild_silentlyExitsWhenNoShopfloorDirectory() async {
        // Container resolved but no .shopfloor/files/ content
        await store.rebuild()

        XCTAssertEqual(store.lastRebuildResult?.orphansRemoved, 0,
            "rebuild() with no .shopfloor directory must report 0 orphans removed")
    }

    // MARK: - contentType(forFilename:) (Sprint 3)

    func test_contentType_returnsLinkForShareSheetCapture() throws {
        try store.createCapture(
            title: "cool article",
            body: "",
            sourceURL: "https://example.com/article",
            captureMethod: "share_sheet"
        )
        let mdPath = try XCTUnwrap(mock.files.keys.first { $0.hasSuffix(".md") })
        let filename = URL(fileURLWithPath: mdPath).lastPathComponent

        let result = store.contentType(forFilename: filename)
        XCTAssertEqual(result, "link",
            "contentType(forFilename:) must return 'link' for share_sheet + sourceURL captures")
    }

    func test_contentType_returnsNilWhenNotInIndex() {
        let result = store.contentType(forFilename: "not-in-index.md")
        XCTAssertNil(result, "contentType must return nil when filename is not in the index")
    }

    // MARK: - makeFilename collision (Sprint 3)

    func test_createCapture_uniqueFilenameOnSlugCollision() throws {
        // "My Story!" and "My Story?" produce the same slug; within the same second
        // they'd produce the same filename — the second must get a counter suffix.
        try store.createCapture(title: "My Story!", body: "first")
        try store.createCapture(title: "My Story?", body: "second")

        let mdFiles = mock.files.keys.filter { $0.hasSuffix(".md") }
        XCTAssertEqual(mdFiles.count, 2, "Both captures must produce distinct .md files")

        let filenames = mdFiles.map { URL(fileURLWithPath: $0).lastPathComponent }
        let uuids = filenames.compactMap { store.filenameToUUID[$0] }
        XCTAssertEqual(Set(uuids).count, 2, "Both captures must have distinct UUID index entries")
    }

    // MARK: - deleteNotebook

    func test_deleteNotebook_removesContentsAndMetadata() async throws {
        let base = try XCTUnwrap(store.rootURL)
        let notebookURL = base.appendingPathComponent("Research", isDirectory: true)
        try store.createCapture(title: "My Note", body: "", notebook: notebookURL)

        let mdPath = try XCTUnwrap(mock.files.keys.first { $0.hasSuffix(".md") })
        let jsonPath = try XCTUnwrap(mock.files.keys.first { $0.contains(".shopfloor/files") && $0.hasSuffix(".json") })
        let filename = URL(fileURLWithPath: mdPath).lastPathComponent
        XCTAssertNotNil(store.filenameToUUID[filename], "Index must be populated before delete")

        try await store.deleteNotebook(at: notebookURL)

        XCTAssertNil(mock.files[mdPath], ".md file must be removed when notebook is deleted")
        XCTAssertNil(mock.files[jsonPath], ".json record must be removed when notebook is deleted")
        XCTAssertNil(store.filenameToUUID[filename], "Index entry must be removed when notebook is deleted")
    }

    // MARK: - filenameToUUID index (Sprint 2)

    func test_createCapture_updatesFilenameToUUIDIndex() throws {
        try store.createCapture(title: "Index Me", body: "")

        let mdPath = try XCTUnwrap(mock.files.keys.first { $0.hasSuffix(".md") })
        let filename = URL(fileURLWithPath: mdPath).lastPathComponent

        XCTAssertNotNil(store.filenameToUUID[filename],
            "filenameToUUID must be populated immediately after createCapture")
    }

    func test_filenameToUUID_warmsOnFirstContentsCall() throws {
        let base = try XCTUnwrap(store.rootURL)
        let inboxURL = base.appendingPathComponent("Inbox", isDirectory: true)
        let shopfloorURL = base.deletingLastPathComponent()
            .appendingPathComponent(".shopfloor/files", isDirectory: true)

        // Simulate pre-existing files (written directly, not via createCapture)
        let meta = CaptureMetadata.make(filename: "existing.md", notebookPath: inboxURL.path)
        let jsonData = try JSONEncoder().encode(meta)
        mock.files[shopfloorURL.appendingPathComponent("\(meta.uuid).json").path] = jsonData
        mock.files[inboxURL.appendingPathComponent("existing.md").path] = Data()

        XCTAssertFalse(store.indexIsWarmed, "Index must not be warmed before contents(of:) is called")

        _ = try store.contents(of: inboxURL)

        XCTAssertTrue(store.indexIsWarmed, "Index must be warmed after first contents(of:) call")
        XCTAssertEqual(store.filenameToUUID["existing.md"], meta.uuid,
            "Pre-existing file must appear in the index after warming")
    }

    // MARK: - ensureInbox DI fix (Sprint 2)

    func test_ensureInbox_usesInjectedFileStore() async throws {
        let freshMock = MockFileStore()
        let freshStore = CaptureStore(fileStore: freshMock)
        await freshStore.resolveContainer()

        try await freshStore.ensureInbox()

        XCTAssertTrue(freshMock.directories.contains { $0.hasSuffix("/Inbox") },
            "ensureInbox must use the injected fileStore, not FileManager.default")
    }
}

# Session: Rebuild Import + External File Detection
**Date:** 2026-04-17
**Branch:** feat/rebuild-import-external-files
**Type:** Bug-fix sprint

---

## What Was Done

Two bugs reported after device testing. One is a code fix (shipped here). One is an installation issue (documented below).

### 1. External files not picked up by Rebuild Library

**Root cause (two parts):**

**Part A — rebuild() only cleaned, never imported.** `rebuild()` scanned `.shopfloor/files/*.json` for orphaned records (no matching `.md`) and deleted them. It never scanned the notebooks for `.md` files that appeared _without_ a sidecar. If Karen dropped a `.md` into her Inbox via Files.app, it had no `.shopfloor/files/[UUID].json`, so the index never knew about it and Rebuild Library did nothing for it.

**Part B — NSMetadataQuery didn't trigger a view refresh.** When a new `.md` file synced in from another device or the Files app, NSMetadataQuery fired and `rebuildIndex()` ran — but the view had no way to know. `filenameToUUID` is `private(set)`, not `@Published`. The list stayed stale until Karen navigated away and back, or pulled to refresh.

**Fix:**

- `rebuild()` now has two steps:
  1. (existing) Remove orphaned `.json` records
  2. (new) `importExternalFiles(from:)` — scans all notebooks recursively for `.md` files not yet in the index, creates `.shopfloor/files/[UUID].json` sidecars for each with `captureMethod: "import"`

- Added `@Published var lastIndexUpdate: Date` to `CaptureStore`. Set at the end of `rebuildIndex()`. `NotebookBrowserView` observes it via `.onChange` and calls `refresh()` automatically — so files added externally appear without any manual gesture.

- `RebuildResult` gains `filesImported: Int`. SettingsView now shows `"N orphans removed · M files imported"`.

- `collectMdFiles(in:)` now uses `fileStore.isDirectory(at:)` instead of `url.resourceValues` so directory traversal works correctly in tests. Added `isDirectory(at:)` to `FileStoring` protocol with `FileManager` + `MockFileStore` implementations.

- `MockFileStore.contentsOfDirectory` now also returns direct-child directories (from its `directories` array). This was a pre-existing gap: traversal tests that created subdirectories couldn't enumerate them.

**New tests (45 total, up from 43):**
- `test_rebuild_createsSidecarForExternalFile`
- `test_rebuild_doesNotDuplicateExistingCapture`

### 2. Share extension not visible on phone

**Not a code bug.** The share extension wasn't in `project.yml` until the previous session's commit. Any previous device install didn't include the extension. To see it:

1. Connect iPhone to Mac
2. In Xcode, change the destination from Simulator to your iPhone
3. Build and run the `Capture` scheme (not just CaptureShare)
4. After install, open Safari → share any URL → tap the share button
5. If "Capture" isn't in the top row, scroll the bottom row of share sheet apps and tap "More" (or long-press an existing app to edit)
6. Enable Capture in the list

If the app crashes on share: check Console.app, filter by the extension process name.

---

## Test Count

| Sprint | Tests |
|--------|-------|
| Sprint 3 polish end | 43 |
| This session | 45 |

---

## Repo State at Close

- Branch merged to main via PR #3
- Tests: 45/45
- Build: Capture app + CaptureShare extension (BUILD SUCCEEDED)

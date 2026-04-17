# Session: Sprint 3
**Date:** 2026-04-17
**Branch:** feat/sprint-3-swipe-delete-filename-fix
**Type:** Implementation sprint

---

## What Was Done

All four Sprint 3 items shipped, plus item 0 (pre-existing bug fix). Tests grew from 39 to 42, all passing. Full build succeeds including the new CaptureShare extension target.

### Item 0 — makeFilename collision fix

**Files:** `CaptureStore.swift`
**Why:** Two captures with titles that slugify identically (e.g., "My Story!" vs "My Story?") and are created within the same Unix-second would overwrite each other silently — content destroyed, UUID orphaned.
**Fix:** Added `uniqueFilename(from:in:)` that calls `makeFilename`, checks for path existence, and appends a counter suffix (`-2`, `-3`, …) until unique.
**Test:** `test_createCapture_uniqueFilenameOnSlugCollision`

### Item 1 — Swipe-to-delete

**Files:** `NotebookBrowserView.swift`
**What:** Added `.onDelete` modifier to the `ForEach`. Captures URLs synchronously from the IndexSet before the async delete loop (avoids stale index access). Notebooks are silently skipped. List refreshes after all deletions complete.
**Coverage:** Unit tests for `deleteCapture` already existed from Sprint 2; no new tests needed (swipe-to-delete is a UI concern, not a logic concern).

### Item 2 — NSMetadataQuery migration

**Files:** `CaptureStore.swift`, `ContentView.swift`, `SettingsView.swift`
**What replaced:** The warm-once `warmIndex()` pattern that required a manual "Rebuild Library" tap after cross-device iCloud syncs.
**Architecture:**
- `startMetadataQuery()` — new method, called from `ContentView` after `resolveContainer()`. Not called in tests (NSMetadataQuery requires real iCloud; calling it with MockFileStore would clobber the index with an empty scan).
- `rebuildIndex()` — new private method. Full scan of `.shopfloor/files/*.json` via the injected `fileStore`. Replaces `filenameToUUID` atomically. Called by NSMetadataQuery notifications and by `warmIndex()`.
- `warmIndex()` — now a 2-line guard wrapper around `rebuildIndex()`. Kept as sync fallback for the race where `contents(of:)` is called before NSMetadataQuery fires.
- `disableUpdates()` / `enableUpdates()` sandwich the `rebuildIndex()` call per Apple's NSMetadataQuery recommendation.
**Key decision:** `startMetadataQuery()` is on the public CaptureStore API (not private), called from ContentView explicitly. This keeps NSMetadataQuery out of test setUp — no iCloud interference with MockFileStore. Rebuild Library in SettingsView is now labeled a recovery tool, not a normal-use button.

### Item 3 — P1 contentType fix + Share extension

#### P1 fix
**Files:** `CaptureStore.swift`, `NotebookBrowserView.swift`
**Bug:** `BrowserItem.init` derived contentType from the filename extension, which returned `"text"` (not `"link"`) for URL captures. Every `.md` file looks the same to the filename check.
**Fix:**
- Added `contentType(forFilename:)` to `CaptureStore` — reads stored `contentType` from `.shopfloor/files/[UUID].json`.
- Updated `BrowserItem.init?(url:contentType:)` to accept an optional pre-resolved contentType. Falls back to `ContentType.from(filename:)` for files captured before this fix.
- `NotebookBrowserView.refresh()` now resolves contentType from store before constructing each BrowserItem.
**Tests:** `test_contentType_returnsLinkForShareSheetCapture`, `test_contentType_returnsNilWhenNotInIndex`

#### Share extension
**Files:** `App/CaptureShare/ShareViewController.swift`, `Info.plist`, `CaptureShare.entitlements`, `project.pbxproj`
**What it does:** When Karen taps Share in Safari, the extension receives the URL, derives a title from `url.host`, writes a `.md` file to `Documents/Inbox/` and a `.shopfloor/files/[UUID].json` sidecar — same two-file pattern as main app. `captureMethod: "share_sheet"` + `sourceURL` ensures `contentType: "link"` in the metadata.
**Architecture decisions:**
- Static `nonisolated` methods for file writing — UIViewController is `@MainActor` but file I/O can't run on main thread; `nonisolated static` allows `Task.detached` to call them without crossing actor boundaries (Swift 6 requirement).
- `CaptureMetadata.swift` is shared between main app and extension targets (same source file, two PBXBuildFile entries). No framework needed — the file has no dependencies except Foundation.
- `makeFilename` / `uniqueFilename` are inlined in the extension (it runs in a separate process, can't import CaptureStore).
- NSMetadataQuery in the main app will detect the new `.md` file and call `rebuildIndex()` automatically — no extra wiring needed.
**pbxproj surgery:** Added PBXNativeTarget, PBXSourcesBuildPhase, PBXCopyFilesBuildPhase (dstSubfolderSpec 13 = PlugIns), PBXFileReference × 4, PBXBuildFile × 3, PBXGroup, XCBuildConfiguration × 2, XCConfigurationList, PBXTargetDependency, PBXContainerItemProxy. UUID prefix: `EE0x`.

---

## Test Count

| Sprint | Tests |
|--------|-------|
| Sprint 2 end | 39 |
| Sprint 3 end | 42 |

New tests: `test_createCapture_uniqueFilenameOnSlugCollision`, `test_contentType_returnsLinkForShareSheetCapture`, `test_contentType_returnsNilWhenNotInIndex`

---

## Known Gaps / Next Session

- Share extension has **not been device-tested** (requires real device + iCloud). Simulator cannot test `url(forUbiquityContainerIdentifier:)`. First device run will validate end-to-end.
- `makeFilename` is duplicated between `CaptureStore` and `ShareViewController`. If the slug logic ever changes, both need updating. Acceptable for now — refactoring to a shared framework is Sprint 4+ work.
- The Platform Spec design sessions (§X, §Y, §Z flagged in TODOS.md) are still unstarted. Not blocking app development.

---

## Repo State at Close

- Branch merged to main via PR #2
- Tests: 42/42
- Build: Capture app + CaptureShare extension

# Session: Sprint 3 Prep
**Date:** 2026-04-16
**Type:** End-of-session handoff — written to ensure next session starts clean

---

## Where We Are

Sprint 2 is merged to `main` (PR #1, 2026-04-16). The app builds, 39/39 tests pass.
`main` is the clean starting point for Sprint 3.

---

## Sprint 3 — Starting Order

### 1. Swipe-to-delete (start here)

**What:** Add swipe-to-delete gesture to captures in `NotebookBrowserView`.
**Why first:** It's the first UI surface that calls `deleteCapture` — making the Sprint 2 work visible to Karen. Everything else in Sprint 3 depends on delete being in the UI.

**Implementation sketch:**
- Add `.onDelete` modifier to the `ForEach` in `NotebookBrowserView`
- Call `Task { try? await store.deleteCapture(at: url) }` inside the handler
- Refresh the list after deletion
- Confirm `BrowserItem` provides the URL needed for the delete call

**Tests needed:**
- UI: swipe deletes item from list (integration — may be manual or XCUITest)
- Unit: already covered by `test_deleteCapture_*` tests in Sprint 2

---

### 2. NSMetadataQuery migration

**What:** Replace the warm-once `filenameToUUID` index + manual "Rebuild Library" button with `NSMetadataQuery`-based real-time iCloud change detection.

**Why:** Eliminates the index drift problem. Renames, deletions, and additions from other devices fire `NSMetadataQueryDidUpdate` automatically. Karen never needs to tap "Rebuild Library."

**Migration path:**
- `indexIsWarmed` flag becomes irrelevant (query keeps index live)
- `rebuild()` becomes recovery-only (not a normal launch step)
- "Rebuild Library" in `SettingsView` can be removed or kept as emergency escape hatch
- `filenameToUUID` stays — NSMetadataQuery updates it incrementally

**Depends on:** Swipe-to-delete done first (makes rename/delete conflicts visible, motivates the migration)

---

### 3. Share extension + BrowserItem contentType from JSON

**What:** Implement the iOS Share extension so Karen can capture URLs from Safari. Then fix the P1 bug: `BrowserItem.init` currently derives `contentType` from filename extension, which returns `"other"` for URL captures instead of `"link"`.

**P1 bug fix (blocked on share extension):**
- Add `contentType(forFilename:)` to `CaptureStore` (mirror of `captureNote(forFilename:)`)
- `NotebookBrowserView.refresh()` resolves contentType from store before constructing `BrowserItem`, OR
- Change `BrowserItem` to accept a pre-resolved contentType at construction time

**The `// TODO Sprint 3` comment is at:** `App/Capture/Views/NotebookBrowserView.swift` — `BrowserItem.init?(url:)`

---

## Open Design Questions (to resolve before or during Sprint 3)

### makeFilename collision (flagged by adversarial review)
Two captures with titles that slugify identically (e.g., "My Story!" and "My Story?") produce the same filename. The second `createCapture` overwrites the first file and its `filenameToUUID` entry — silently destroying the first capture's metadata. The `.json` UUID becomes an orphan; `rebuild()` will delete it.

**Fix:** Add a uniqueness check in `makeFilename` — append a counter or UUID suffix if the path already exists. Simple, low-risk. Should be Sprint 3 item 0 (do it before any user testing).

### Platform Spec design sessions (§X, §Y, §Z)
Three spec gaps in TODOS.md should be designed before any cross-factory or compliance code is written. Can run in parallel with Sprint 3 app work (different sessions). Not blocking Sprint 3.

---

## What NOT to do next session

- Don't start with NSMetadataQuery — swipe-to-delete comes first
- Don't touch the Platform Spec items unless the user explicitly calls a design session
- Don't merge anything to main without running tests (39 must stay green)

---

## Key Files for Sprint 3

| File | Why you'll touch it |
|------|---------------------|
| `App/Capture/Views/NotebookBrowserView.swift` | Swipe-to-delete, contentType fix |
| `App/Capture/Services/CaptureStore.swift` | NSMetadataQuery, makeFilename fix, contentType(forFilename:) |
| `App/CaptureTests/CaptureStoreTests.swift` | New tests for every new method |
| New: `App/ShareExtension/` | Share extension target |

---

## Branch Strategy

Sprint 3 work goes on a feature branch, same pattern as Sprint 2:
```
feat/sprint-3-[topic]
```
Create from `main` at the start of next session.

---

## Repo State at Close

- Branch: `main`
- Last commit: `313302e feat: Sprint 2 — captureNote, contentType, deleteCapture, rebuild, filenameToUUID (#1)`
- Tests: 39/39 passing
- Uncommitted: `.claude/settings.local.json`, `Data Structures/.DS_Store`, `Design Documents/ShopFloor Platform Spec.md` — none are app code, all safe to ignore

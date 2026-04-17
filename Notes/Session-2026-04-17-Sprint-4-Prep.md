# Session: Sprint 4 Prep
**Date:** 2026-04-17
**Type:** End-of-session handoff — written to ensure next session starts clean

---

## Where We Are

Sprint 3 is merged to `main`. The app builds with two targets: `Capture` (main app) and `CaptureShare` (Share extension). 42/42 tests passing.

---

## First Thing Next Session: Device Test the Share Extension

The Share extension has never run on a real device. Before writing any new code, verify it works end-to-end:

1. Build and install on a physical iPhone (requires a real Apple Developer account and signing)
2. Open Safari → share any URL → tap "Capture" in the share sheet
3. Check that:
   - A `.md` file appears in the Capture app's Inbox
   - The item shows a "Link" badge (contentType = link)
   - The capture note is empty (expected — share extension sets no note)
   - The `.shopfloor/files/[UUID].json` sidecar exists with `contentType: "link"` and `sourceURL`

**If it fails:** Common failure modes:
- `url(forUbiquityContainerIdentifier:)` returns nil in extension — check entitlements match exactly (both app and extension must have the same iCloud container ID)
- Extension appears in share sheet but crashes — check Console.app for the extension process
- Files don't appear in main app — NSMetadataQuery should pick them up; try Rebuild Library as fallback

---

## Sprint 4 Candidates (pick at next session)

These are ordered by user-visible value:

### 1. Capture note from Share sheet
**What:** Let Karen add a note at capture time from the share sheet UI. Currently `ShareViewController` shows "Saving to Capture..." and immediately dismisses — no user input.
**How:** Add a `UITextView` to `ShareViewController`, let Karen type a brief note, then write it to `captureNote` in the metadata.
**Why:** High value — Karen's "why I saved this" note is most useful at capture time.

### 2. Rename / move support
**What:** Karen should be able to rename a capture or move it between notebooks from `CaptureDetailView`.
**Why:** Currently the filenameToUUID index can drift if Karen renames via Files app. NSMetadataQuery will catch the change eventually, but rename UX inside the app is cleaner.

### 3. Pull-to-reveal search / filter in NotebookBrowserView
**What:** A search bar that filters the capture list by title.
**Why:** As the library grows, scanning a long list is painful.

### 4. Platform Spec design sessions
**What:** Three open design questions in TODOS.md (§X, §Y, §Z) about cross-factory behavior and compliance. Design sessions, not code.
**Why:** Not blocking current app development, but will be needed before any skill execution work starts.

---

## Key Files for Sprint 4

| File | Why you'll touch it |
|------|---------------------|
| `App/CaptureShare/ShareViewController.swift` | Note input UI |
| `App/Capture/Views/CaptureDetailView.swift` | Rename/move UX |
| `App/Capture/Views/NotebookBrowserView.swift` | Search/filter |
| `App/Capture/Services/CaptureStore.swift` | Any new store methods |
| `App/CaptureTests/CaptureStoreTests.swift` | Tests for new methods |

---

## Branch Strategy

Same pattern as Sprint 2 and Sprint 3:
```
feat/sprint-4-[topic]
```
Create from `main` at the start of next session.

---

## Repo State at Session Start

- Branch: `main`
- Last commit: Sprint 3 merge (PR #2)
- Tests: 42/42
- Targets: Capture (app), CaptureShare (Share extension), CaptureTests

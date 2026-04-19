# Session 2026-04-19 — Bug Fixes

## What Happened

Karen filed 5 bugs in her iCloud Bugs folder inside the Capture app. Each was a `.md` file;
two bugs included a companion image as the primary instruction (the note body was empty —
the image IS the spec).

This session worked through all 5 in order.

---

## Bugs Worked

### Bug 1: Design Pattern For TableRow Cells

**Reference image:** `design-pattern-for-tablerow-cells.png` — screenshot of the Notebooks App
(Alfons Schmidt) showing compact single-line rows with small icons and no metadata.

**Change:** `CaptureCardRow` and `NotebookRowLabel` in `NotebookBrowserView.swift`

- Icon box reduced from 64×64 → 36×36 (corner radius 10 → 8)
- Icon SF Symbol font size reduced from 26pt → 16pt
- Removed note preview text from row
- Removed date/domain metadata from row
- Row vertical padding reduced from 6pt → 4pt
- Title limited to single line (lineLimit 2 → 1)
- Removed unused `note`, `createdAt`, `sourceURL` params from `CaptureCardRow` init
- Removed unused `domain` and `dateText` computed properties
- iCloud syncing row also compacted (64×64 → 36×36)

**Before:** Stash-style card rows with big thumbnails and multi-line metadata.
**After:** Compact Notebooks-style rows — icon + title only, very tight.

---

### Bug 2: Image Pill Needs Adjustment

**Note:** "Make entire pill smaller including font size"

**Changes:**
- `CaptureCardRow.typeBadge` (in `NotebookBrowserView.swift`): font 9/10pt → 7/7pt, padding H:6 V:3 → H:4 V:2, spacing 3 → 2
- `CaptureDetailView.linkMetadataBar` pill: font 9/10pt → 7/7pt, padding H:8 V:4 → H:5 V:2

---

### Bug 3: IMG_0431

**Reference image:** `img0431.jpg` — screenshot from another app showing a document detail view
with a prominent blue circle checkmark button (⊙✓) in the navigation bar trailing position.

**Interpretation:** Karen wants a visual "Done editing" affordance in the nav bar when
actively editing body text — more prominent than the existing keyboard accessory toolbar button.

**Change:** `CaptureDetailView.swift` toolbar

When `isEditingBody == true`, the `+` and `ellipsis.circle` buttons are replaced by a blue
`checkmark.circle.fill` button (26pt) that calls `markdownCoordinator?.dismissKeyboard()`.
When editing stops, the normal toolbar buttons return.

---

### Bug 4: On a Quick Capture, Ability to Title

**Note:** "On quick capture, make it a little bit more obvious to Karen that she can title it
by making the blank title text field a little bit more prominent"

**Change:** `CreateCaptureView.swift`

- Added `@FocusState private var titleFocused: Bool`
- Title `TextField` given `.font(.system(size: 18, weight: .semibold))` (was default body)
- `.focused($titleFocused)` on the title field
- `.onAppear { titleFocused = true }` on the Title section — keyboard auto-opens on the title
  field the moment Karen opens quick capture

---

### Bug 5: 1.6 Add Go To to Upper-Right Menu

**Note:** "Add a go-to option to the upper-right menu. When selected, this option will invoke
a navigation tree and move Karen to the specified point in the tree. This option should always
be available."

**New file:** `GoToPickerView.swift`

- `GoToPickerView`: modal sheet with NavigationStack showing the full tree
- `GoToLevelView`: shows notebooks (with NavigationLink to drill deeper) and documents (tap to
  navigate). A "Go Here" button appears at every non-root level to jump directly to a notebook.
- `Notification.Name.navigateToURL` posted when Karen makes a selection

**Change:** `ContentView.swift`
- Added `.onReceive(navigateToURL)` handler that sets `navigationPath = [targetURL]`
  (replacing the full path — a clean jump to anywhere in the tree)

**Change:** `NotebookBrowserView.swift`
- Added `@State private var showGoTo = false`
- Added "Go To..." menu item (with `arrow.right.circle` icon) with a `Divider` separating
  it from the New Capture / New Notebook items
- Added `.sheet(isPresented: $showGoTo)` presenting `GoToPickerView`

**GoToPickerView.swift** added to `Capture.xcodeproj` (PBXFileReference + PBXBuildFile +
Sources build phase entry).

---

## Build Status

`** BUILD SUCCEEDED **` — clean build, no errors.

---

## What's Next (updated priority queue)

1. **Device test** — all 5 bug fixes plus the previous 9 enhancements need on-device validation
2. **Raw title backfill** — on `CaptureDetailView.load()`, if `titleIndex[filename]` is nil,
   read first `# ` heading from body and write as `displayTitle`
3. **MCP Sprint** — `App/MCPServer/` Swift target (gates on Task 0 audit of CaptureStore for
   iOS-specific imports)

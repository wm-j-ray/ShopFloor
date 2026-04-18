# Session Notes — 2026-04-18 Sprint 4 Polish

## What We Did

### Stash-style card rows (NotebookBrowserView)
- Replaced compact icon+title `BrowserRowLabel` with full card layout
- 64pt square thumbnail: actual photo for image captures, tinted icon card for text/PDF/link
- Content-type badge overlaid bottom-left of thumbnail (colored pill: purple/Text, blue/Link, orange/PDF, teal/Image)
- Title (semibold, 2 lines), captureNote preview (gray, 2 lines), domain·date bottom line
- Domain extracted from `sourceURL`, formatted as "chatgpt.com · 2h ago" or "chatgpt.com · Apr 15"
- `BrowserItem.capture` extended with `note`, `createdAt`, `sourceURL`, `companionURL`
- Image thumbnails load async via `.task(id:)` on background thread

### Notebook rows with counts
- 64pt folder icon (blue tinted)
- Count line: "3 items · 1 notebook" or "Empty"
- Counts populated during `refresh()` via a `contents(of:)` call per notebook

### CaptureStore: metadata(forFilename:)
- Single JSON read returns full `CaptureMetadata` — replaces triple calls to contentType/captureNote/displayTitle

### Link detail view (CaptureDetailView)
- New `linkBody` branch for `contentType == "link"`
- Hero: full-width gradient placeholder (220pt), entire area tappable → opens URL in Safari
- "Open" salmon pill is a visual affordance only (not a separate tap target)
- Title + globe icon + domain below hero
- Long press on title → rename alert
- Metadata bar: calendar date · globe domain · Link badge
- Nav bar: pencil·circle·fill icon + title tappable → rename alert

### Affordance design language (established as convention)
- Pencil icon = this field is editable (tap or long press)
- No icon = read-only information
- Ghost text "Tap to add a note..." = empty editable field
- Notes section redesigned: "Notes ✏️" heading, tappable content/ghost text, no separate pencil button

### Karen's Enhancements notebook
- Discovered Karen is using the Capture app itself to communicate enhancement requests
- Read 6 enhancement notes from the Enhancements notebook in iCloud

## Enhancements Read (from Enhancements notebook)
1. **Quick capture title** — first line of shared text becomes title
2. **Remember where you were** — state restoration on relaunch (empty note, concept only)
3. **Renaming** — long press on detail page title (partially done: nav bar pencil + long press)
4. **Saving links** — background OG fetch: title, image, abstract
5. **Setting target folder** — notebook tree picker in share sheet (non-blocking, inbox default)
6. **Sorting** — drag handles, alpha/date options (empty note, concept only)

## Files Changed
- `App/Capture/Views/NotebookBrowserView.swift` — full row rewrite + BrowserItem extension
- `App/Capture/Views/CaptureDetailView.swift` — link detail view + affordance redesign
- `App/Capture/Services/CaptureStore.swift` — metadata(forFilename:) helper

## Commit
`a4b7ce0` — Sprint 4 polish: Stash-style card rows, link detail view, affordance language

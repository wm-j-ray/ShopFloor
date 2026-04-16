# ShopFloor TODOs

---

## App / Sprint 3 Items (deferred from Sprint 2 adversarial review)

### BrowserItem shows wrong contentType for link captures (P1)

**What:** `BrowserItem.init` derives `contentType` from the filename extension, so share-sheet captures (stored as `.md` but with `contentType: "link"` in the JSON) display as "Text" in the browser list instead of "Link". Silent data display error.

**Fix:** Pass a `contentType` lookup function into `NotebookBrowserView` from the parent, or resolve contentType from the store's index before constructing `BrowserItem`. Requires the store to expose a `contentType(forFilename:)` method (mirror of `captureNote(forFilename:)`).

**Current state:** `// TODO Sprint 3` comment at `BrowserItem.init?:contentType` call site. Blocked on share extension work.

**Priority:** P1 — user-visible data accuracy bug, but only affects share-sheet captures which aren't implemented in Sprint 2.

---

### rebuild() runs on every app foreground — no debounce (P2)

**What:** `ContentView.task` fires on every foreground/scene-return. `rebuild()` scans `.shopfloor/files/` every time. At scale (hundreds of captures, iCloud latency), this adds unnecessary I/O.

**Fix:** Skip rebuild if `lastRebuildResult != nil` (already ran this session), or add a timestamp guard (run at most once per session / per N minutes).

**Current state:** Acceptable for Sprint 2 scale. Flag before NSMetadataQuery migration in Sprint 3.

**Priority:** P2 — performance, not correctness.

---

### captureNote(forFilename:) reads disk on every call — no caching (P2)

**What:** Called from `CaptureDetailView.load()` on every navigation to a capture. Reads and decodes the entire `.json` file each time. No caching.

**Fix:** Cache note in `filenameToUUID`-adjacent dictionary, or batch-load all captureNotes during `warmIndex()`. Sprint 3 NSMetadataQuery work is the right moment to do this properly.

**Priority:** P2 — performance, tolerable at Sprint 2 scale.

---

## Platform Spec — Future Sessions (pre-Sprint 3 or Sprint 3)

### §X: Cross-Instance Federation and M&A Protocol

**What:** ShopFloor instances are factories. Multiple factories can exist independently
(each with its own `.shopfloor/`, foreman, and skill set). The platform needs a formal
protocol for three operations:

1. **Federation** — Factory A borrows a specific skill from Factory B without merging.
   Karen uses Factory B's Developmental Editor while her files stay in Factory A's
   `.shopfloor/`. Factory B's skill updates propagate automatically. Factory A does not
   own the skill; it references it.

2. **Skill lending for onboarding** — Factory B lends one or two "whiz-bang" skills to
   Factory A on a time-limited or trial basis. Karen experiences something magical.
   She either upgrades (gets the full Factory B skill set) or the lending expires.
   This is the Gillette model at the factory level: skill packs as blades, ShopFloor as
   the razor handle. Conversion tracking hooks belong here.

3. **Merger/Acquisition** — One factory absorbs another. All records, skills, and content
   consolidate under one `.shopfloor/`. The absorbed factory's entry in `global-registry.json`
   is marked `status: "merged"` with a pointer to the absorbing factory. Old skill references
   resolve through the merger pointer.

**Technical primitives already in place:**
- UUID layer: globally unique file identities survive cross-factory moves with no collision risk
- `~/.shopfloor/global-registry.json`: the town registry; all factories register here
- `external_skills` in `contextFingerprint` (proposed): cross-factory skill reference declaration
- `hoist(subdomain:into:)`: the atomic merge primitive (see deleteCapture design doc)
- `.shopfloor/` boundary rule: recursion stops at sub-`.shopfloor/`; independent domains
  are respected until explicitly told otherwise

**Known trade-off to address in this session:**
- `notebookPath` is an absolute path (e.g., `/Users/wmjray/iCloud Drive/ShopFloor/...`).
  During a merger where files physically move, all `.json` records need a `notebookPath`
  rewrite pass. If files stay in place (acquisition, no physical move), no rewrite needed.
  Future improvement: store `notebookPath` relative to factory root — makes mergers
  zero-rewrite. This is a schema migration; flag as a known trade-off, not a blocker.

**Skill conflict resolution rule (to lock in this session):**
- When two factories have a skill with the same name, the owning factory wins.
- Borrowing factory can alias but not override.
- Analogous to a staffing agency: the worker follows the agency's rules, not the client's.

**Shutdown independence (non-negotiable principle to lock in Platform Spec):**
- ShopFloor is infrastructure. Karen's `.md` files are her data. These are never the same thing.
- Removing or disabling a ShopFloor instance (deleting `.shopfloor/`, unregistering a vertical,
  or hitting `platform.halt`) never touches Karen's content files.
- Three shutdown modes:
  - `platform.halt` file: pauses AI execution, preserves everything, no content impact
  - Vertical unregistration: removes skills from registry, Karen's files untouched
  - Full ShopFloor removal: delete `.shopfloor/` entirely, Karen's `.md` files survive intact
- This principle must be stated explicitly in Platform Spec §1 (or §0 as a design axiom).
  It is the trust contract between the platform and the user.

**Depends on:** Sprint 2 complete. Should be designed before any cross-factory feature is coded.

---

### §Z: NSMetadataQuery Migration — Real-Time iCloud Change Detection

**What:** Replace the Sprint 2 warm-once filenameToUUID index + manual "Rebuild Library"
escape hatch with `NSMetadataQuery`-based real-time change detection.

**Why this matters:** `NSMetadataQuery` is Apple's mechanism for watching iCloud file changes
as they happen — renames, deletions, additions from other devices all fire `NSMetadataQueryDidUpdate`
notifications. This eliminates:
- The manual "Rebuild Library" button in Settings (Karen should never need it)
- The rename-gap: when Karen renames a file externally, the index updates automatically
- The sync-window false-positive risk: evicted files show up in query results with correct
  downloading status before rebuild() has a chance to misclassify them

**What Sprint 2 ships instead (by design):** warm-once index + Task.detached rebuild at launch
+ manual trigger in Settings. This is correct for Sprint 2 scope. NSMetadataQuery adds
meaningful complexity (dedicated query thread, start/stop lifecycle, delegate protocol).

**Migration path:** When NSMetadataQuery is implemented:
- `indexIsWarmed` flag becomes irrelevant (query keeps index live)
- `rebuild()` becomes a recovery-only operation (not a normal launch step)
- "Rebuild Library" in Settings can be removed or kept as emergency escape hatch
- `filenameToUUID` index stays — NSMetadataQuery updates it incrementally

**Depends on:** Sprint 2 complete. Natural Sprint 3 improvement after swipe-to-delete lands
(swipe-to-delete is the first UI feature that makes external rename/delete conflicts visible to Karen).

---

### §Y: Directory Compliance Operations

**What:** Platform operations for making an existing directory tree ShopFloor-compliant,
checking compliance status, and merging independent compliance domains.

**Operations:**

1. `isCompliant(at directory: URL) -> ComplianceReport`
   - Checks: `.shopfloor/files/` exists, every tracked file has a `.json` record, no orphans
   - Stops recursion at sub-`.shopfloor/` boundaries — independent domains are NOT failures
   - Returns `ComplianceReport` with: `isCompliant`, `untrackedFiles`, `orphanedRecords`,
     `independentSubdomains`

2. `adoptExistingFiles(in directory: URL) async`
   - Walks directory tree, creates `.json` records for files with no metadata
   - Uses `captureMethod = "import"`, `contentType` derived from extension
   - Stops at sub-`.shopfloor/` boundaries (does NOT absorb independent domains silently)
   - Non-blocking: call via `Task.detached` like `rebuild()`

3. `hoist(subdomain subDirectory: URL, into parentDirectory: URL) async throws`
   - Merges a subdirectory's `.shopfloor/` into the parent's
   - Copies all `.json` records from sub to parent `.shopfloor/files/`
   - Updates `filenameToUUID` index
   - Checks for filename collisions before proceeding (fails loudly, never silently overwrites)
   - Deletes sub `.shopfloor/` after successful transfer
   - This is the atomic primitive for M&A at the directory level

**macOS note:** On macOS with `com.apple.security.files.user-selected.read-write` entitlement
and security-scoped bookmarks, these operations can be run against any user-selected directory.
On iOS, sandbox restricts this to the app's container. Same code, different entitlements.

**Depends on:** Sprint 2 complete (FileStoring protocol, ShopfloorFileActor established).

---

## Sprint 3

### BrowserItem contentType must read .shopfloor JSON for share-sheet captures

**What:** When the share extension lands in Sprint 3, `BrowserItem.init?(url:)` currently derives `contentType` from file extension. For "link" captures (no file extension, stored `contentType = "link"`), extension-based derivation produces `"other"` — diverging from the stored value.

**Why:** The content type badge in `NotebookBrowserView` would show "Other" instead of "Link" for URL captures. Wrong data shown to Karen.

**How:** `BrowserItem.init` needs to either:
- Read `.shopfloor/files/[UUID].json` asynchronously to get stored `contentType`, OR
- Receive a pre-loaded `contentType` map from `CaptureStore` (passed into the view)

The async read approach conflicts with `BrowserItem.init?` being synchronous — likely requires a design change to how `NotebookBrowserView` populates its items.

**Current state:** `BrowserItem.init` calls `ContentType.from(filename: url.lastPathComponent)` — correct for Sprint 2 (no share extension, URL captures can't appear in the list). The Sprint 2 code has a `// TODO Sprint 3` comment at this call site.

**Depends on:** Share extension implementation (Sprint 3 scope)

---

### DRY up the .shopfloor write path

**What:** After Sprint 2, two places encode-and-write a `CaptureMetadata`: `CaptureStore.writeMetadata()` (create path) and `ShopfloorFileActor.readModifyWrite()` (update path). If a third write path appears (e.g., `deleteCapture`, `updateFilename`), extract a shared static encode-and-write helper.

**Why:** Two call sites is fine. Three is a DRY violation. Waiting until the third site appears before extracting is the right call.

**Current state:** Both call sites are ~5 lines: `JSONEncoder().encode(metadata)` + `fileStore.createFile(atPath:)`. Low risk of drift while there are only 2.

**Depends on:** Whichever Sprint 3 feature adds a third write path (likely `deleteCapture` or rename support)

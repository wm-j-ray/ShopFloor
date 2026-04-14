# ShopFloor — Platform Specification
**Version:** 1.0 (Design Phase)
**Status:** In progress — written concept-by-concept in working session 2026-04-14
**Author:** Bill (architecture), Claude (documentation)
**Derived from:** ShopFloor Storage Spec v1.0 (concept-assignment pass)
**Governing principle:** Subject matter expertise is the domain of the vertical. ShopFloor knows nothing about fiction. StoryEngine knows nothing about platform internals.

---

## Tier Systems (Two — Do Not Conflate)

### Product Tiers (0 / 1 / 2) — What Karen's subscription gives her
| Tier | Name | What Karen gets |
|------|------|----------------|
| 0 | Stash + Readwise | File capture, notebooks, search, resurface. No AI. Free. |
| 1 | Prompt Cookbook | Same UI. Claude pre-cooks prompts Karen pastes into any AI. Paid one-time. |
| 2 | Hyperdrive | Same UI. Claude executes natively. Full AI. Subscription. |

### Skill Architecture Tiers (1 / 2 / 3) — A skill's role on the platform floor
| Tier | Name | What it does |
|------|------|-------------|
| 1 | Floor management | Keeps the platform running. Invisible to Karen. Foreman's domain. |
| 2 | Quality control | Evaluation, validation, gate enforcement. |
| 3 | Production | Direct value delivery to Karen. Creative work. |

The `tier` field in SKILL.md refers to skill architecture tier (1/2/3), not product tier.
The `product_tier_compatibility` field in VERTICAL.md refers to product tier (0/1/2).

---


---

## 1. File System Architecture

### 1.1 Hidden Directory Convention

All ShopFloor infrastructure lives in directories prefixed with `.` (period). On macOS and iOS, dot-prefixed files and directories are hidden from Finder, Files app, and most file browser UIs by default. A technical user can reveal them (`Cmd+Shift+.` in Finder), but they are invisible to Karen by convention.

The platform directory name is `.shopfloor/`. Every vertical's infrastructure — object model, audit trail, session state, skill registry — lives inside `.shopfloor/`. This convention applies regardless of which vertical is installed.

No metadata files are placed alongside content files. No `.DS_Store`-style pollution in Karen's view of her work. The Notebooks App (Alfons Schmidt) pattern — where every `.md` file has a visible sibling `.md.plist` — is the explicit anti-pattern this architecture avoids.

### 1.2 UUID Layer

Every file Karen creates — or that the system creates on her behalf — receives a UUID at birth. The UUID is:
- Assigned once, at file creation
- Stored in the per-file metadata record
- Stored in the project manifest
- Stored in every object model record that references the file
- **Never changed** when Karen renames, moves, or reorganizes the file

The human-readable filename is the *display name*. The UUID is the *identity*. They can diverge freely.

File identity is a platform service. Verticals consume UUIDs — they do not generate or manage them.

### 1.3 Per-File Metadata Record

Location: `.shopfloor/files/[first-8-chars-of-UUID].json`

Named by UUID prefix to avoid filename collisions when Karen has identically-named files in different subdirectories.

**Platform base schema:**
```json
{
  "uuid": "8F3A2C1D-4B5E-6789-ABCD-EF0123456789",
  "displayName": "Chapter One",
  "currentFilename": "Chapter One.md",
  "relativePath": "Chapter One.md",
  "fileType": "page",
  "parentUUID": "1A2B3C4D-5E6F-7890-ABCD-EF0123456789",
  "schemaVersion": "1.0",
  "dateCreated": "2026-04-11T14:23:00Z",
  "dateModified": "2026-04-11T16:45:00Z",
  "status": "active"
}
```

Field notes:
- `relativePath`: path relative to the project root. Used by orphan detection to locate files without a full tree search.
- `fileType`: `page` (document) or `book` (container/folder). Platform-defined enum.
- `status`: `active` or `orphaned`. Platform-managed.

**Vertical extensions:** Verticals may add fields to this record by declaring them in their `VERTICAL.md` under `per_file_extensions`. The Foreman validates that no two verticals claim the same extension field names. Extension fields are namespaced by vertical ID (e.g., `storyengine_isParticle`). Platform-native fields listed above are reserved and cannot be overridden.


### 1.4 Container Manifest (`manifest.json`)

Location: `.shopfloor/manifest.json` inside each project folder.

The project's table of contents. Tracks every content file and every object model entity the platform knows about.

**Platform schema:**
```json
{
  "containerUUID": "1A2B3C4D-5E6F-7890-ABCD-EF0123456789",
  "containerName": "My Novel",
  "schemaVersion": "1.0",
  "dateCreated": "2026-04-01T09:00:00Z",
  "dateModified": "2026-04-11T16:45:00Z",
  "shopfloorVersion": "1.0.0",
  "activeVertical": "storyengine",
  "fileRegistry": [
    {
      "uuid": "8F3A2C1D-4B5E-6789-ABCD-EF0123456789",
      "currentFilename": "Chapter One.md",
      "relativePath": "Chapter One.md",
      "fileType": "page",
      "status": "active"
    }
  ],
  "idCounters": {},
  "objectModelRegistry": [],
  "orphanRegistry": []
}
```

**`idCounters`:** The counter mechanism is platform — it ensures no two entities receive the same ID within a project. The counter *keys* (e.g., `CHR`, `SCN`, `WND`) are vertical-defined entity type prefixes, declared in the vertical's `VERTICAL.md` under `entity_types`. The platform initializes counters for each declared type when a project is created. Format: `{ "CHR": 2, "SCN": 0 }`.

**`objectModelRegistry`:** Platform structure, vertical content. The registry entry schema is platform-defined (entityID, entityType, schemaVersion, dateCreated). The entityType values are vertical-defined (e.g., `Character_Profile`, `Scene_Container`).

**`activeVertical`:** Replaces `activeTeam` from the Storage Spec v1.0. Records which vertical is active for this project. Set at project creation, readable by the Foreman for routing.

### 1.5 Audit Trail (`audit/audit.jsonl`)

Location: `.shopfloor/audit/audit.jsonl` inside each project folder. Append-only. Never overwritten, never truncated.

The platform defines the following event types. All events share a base schema:

```json
{
  "event": "EVENT_TYPE",
  "timestamp": "2026-04-13T09:14:00Z",
  "skillId": "skill-name",
  "skillVersion": "1.0",
  "role": "role-id",
  "sessionId": "SES-0042"
}
```

**Platform-defined event types:**

`SKILL_OUTCOME` — recorded every time a skill produces output and Karen responds.
```json
{
  "event": "SKILL_OUTCOME",
  "outcome": "accepted | modified | ignored",
  "entityId": "CHR-003"
}
```

`SKILL_FEEDBACK` — recorded when Karen taps the optional evaluation prompt. Only in `warranty` or `active` evaluation mode.
```json
{
  "event": "SKILL_FEEDBACK",
  "rating": "positive | negative",
  "karensNote": "free text — most actionable signal"
}
```

`CREATE` — recorded when a skill creates an object model entity.
```json
{
  "event": "CREATE",
  "entityId": "CHR-003",
  "entityType": "Character_Profile"
}
```

`UPDATE` — recorded when a skill modifies an existing entity.
```json
{
  "event": "UPDATE",
  "entityId": "CHR-003",
  "fieldsChanged": ["name", "wound"]
}
```

Verticals may define additional event types. Vertical-defined events must include the base schema fields and prefix the event type with the vertical ID (e.g., `STORYENGINE_PARTICLE_PROMOTED`).


### 1.6 Snapshots (`.shopfloor/snapshots/`)

Versioned backups of the project manifest at points in time. Written by the platform before any destructive operation (bulk delete, schema migration, restore).

Naming convention: `YYYY-MM-DD_manifest.json`

Snapshot creation is a platform responsibility. Verticals do not write snapshots and do not need to know snapshots exist.


---

## 2. Registry Architecture

### 2.1 Global Skill Registry (`~/.shopfloor/global-registry.json`)

Location: Platform app data directory — not inside any project folder.

Written by the Foreman during vertical registration. Contains all installed verticals and their declared roles, skills, and schemas. One file for the entire ShopFloor installation.

```json
{
  "schemaVersion": "1.0",
  "dateUpdated": "2026-04-14T18:00:00Z",
  "verticals": {
    "storyengine": {
      "displayName": "StoryEngine",
      "version": "1.0",
      "registeredAt": "2026-04-14T18:00:00Z",
      "roles": ["acquisitions-editor", "publisher", "developmental-editor", "proofreader", "managing-editor"],
      "skills": [
        { "id": "starting-lineup", "path": "Skills/creative/starting-lineup/SKILL.md", "skillTier": 3, "role": "acquisitions-editor" },
        { "id": "greenlight-review", "path": "Skills/creative/greenlight-review/SKILL.md", "skillTier": 3, "role": "publisher" },
        { "id": "skill-designer", "path": "Skills/creative/skill-designer/SKILL.md", "skillTier": 3, "role": "managing-editor" }
      ],
      "schemaPaths": [
        "Data Structures/Noun Data Structures/",
        "Data Structures/Verb Data Structures/",
        "Data Structures/Scaffolding/",
        "Data Structures/Frameworks/"
      ],
      "productTierCompatibility": [0, 1, 2]
    }
  }
}
```

The Foreman is the only writer. Skills and app code are read-only consumers.

### 2.2 Per-Project Skill Registry (`.shopfloor/skills/skill-registry.json`)

Location: Inside each project's `.shopfloor/` directory.

Created at project initialization by copying the active vertical's skill list from the global registry and initializing per-skill evaluation state. Records the active vertical and tracks skill performance for this specific project.

```json
{
  "schemaVersion": "1.0",
  "activeVertical": "storyengine",
  "dateCreated": "2026-04-14T18:00:00Z",
  "skills": {
    "starting-lineup": {
      "skillTier": 3,
      "role": "acquisitions-editor",
      "evaluationMode": "warranty",
      "useCount": 0,
      "warrantyUsesRemaining": 10,
      "lastInvoked": null
    }
  }
}
```

The global registry answers: what is installed? The per-project registry answers: how is it performing here?

### 2.3 Skill Evaluation Modes

Three modes govern how the platform prompts Karen for feedback after a skill runs. Mode is tracked per-skill per-project in the per-project skill registry. Defaults live in `system-manifest.json` under `quality_control`.

| Mode | Trigger | Prompt shown? |
|------|---------|---------------|
| `warranty` | First N uses (default: 10) | Always — full evaluation prompt |
| `active` | Every Nth use after warranty (default: every 3rd) | On trigger use only |
| `passive` | All uses after active threshold | Never — observe only |

Mode transitions are automatic and logged to the audit trail. `SKILL_FEEDBACK` events are only recorded in `warranty` and `active` modes. In `passive` mode, `SKILL_OUTCOME` still records accepted/modified/ignored.

Default thresholds are configurable in `system-manifest.json`. Per-project overrides are not supported in v1.0.


---

## 3. System-Level Files

### 3.1 System Manifest (`system-manifest.json`)

Location: Product root `.shopfloor/system-manifest.json` — one per installation, not per-project.

Runtime operational state and platform configuration. Read by the Foreman on every session init.

```json
{
  "schemaVersion": "1.0",
  "shopfloorVersion": "1.0.0",
  "dateCreated": "2026-04-14T09:00:00Z",
  "dateModified": "2026-04-14T18:00:00Z",
  "activeVertical": "storyengine",
  "activeProjectCount": 3,
  "quality_control": {
    "warrantyLength": 10,
    "activeFrequency": 3
  },
  "productTier": 2
}
```

`productTier` — the current product tier (0, 1, or 2) for this installation. Determines which skills are executable vs. human-readable.

### 3.2 Session State (`session-state.json`)

Location: `.shopfloor/session-state.json` inside each project folder.

The platform owns the schema envelope. The active vertical owns the payload inside `state`.

**Platform envelope (always present):**
```json
{
  "schemaVersion": "1.0",
  "sessionId": "SES-0042",
  "timestamp": "2026-04-14T18:00:00Z",
  "activeVertical": "storyengine",
  "activeRole": "acquisitions-editor",
  "state": {}
}
```

`state` — vertical-defined payload. ShopFloor writes the envelope fields and passes `state` through without interpretation. The active vertical's session-init skill populates and reads `state`. Platform code never inspects `state` contents.

### 3.3 Write-Back Contract

The sequence every skill must follow when creating or updating an object model entity. No exceptions. The platform enforces this discipline; the vertical provides the entity types.

**For entity creation:**
1. Acquire next ID — read `idCounters[TYPE]` from `manifest.json`, increment, write back immediately (lightweight lock)
2. Instantiate template — copy the entity type's JSON template, populate fields, set `schemaVersion`, `profileVersion: 1`, `dateCreated`, `dateModified`
3. Write object model record — save to `.shopfloor/object-model/` using `[EntityType]_[ID].json`
4. Update cross-references — for every entity referenced by the new record, update that entity's linking arrays
5. Register in manifest — add to `objectModelRegistry` with entityID, entityType, schemaVersion, dateCreated
6. Log to audit — append `CREATE` event to `audit.jsonl`

**For entity update:**
1. Read current record
2. Apply changes to affected fields only
3. Increment `profileVersion`
4. Set `dateModified` to now
5. Update cross-references if linked entities changed
6. Write record (overwrite in place)
7. Log to audit — append `UPDATE` event with `fieldsChanged` array

The write-back contract applies identically across all verticals. Only the entity types, templates, and field names differ.


---

## 4. Performance Tracking

### 4.1 Scorecard

Location: `.shopfloor/object-model/Scorecard_[ROLE-ID].json` inside each project folder.

Per-role per-project performance summary. Written by the platform's scorecard-updater skill (skill tier 1) after each `SKILL_OUTCOME` event. Read by the Foreman to determine skill evaluation mode transitions.

```json
{
  "schemaVersion": "1.0",
  "roleId": "acquisitions-editor",
  "projectUUID": "1A2B3C4D-...",
  "dateCreated": "2026-04-14T09:00:00Z",
  "dateModified": "2026-04-14T18:00:00Z",
  "invocations": 12,
  "accepted": 8,
  "modified": 3,
  "ignored": 1,
  "acceptanceRate": 0.67,
  "modificationRate": 0.25,
  "ignoredRate": 0.08
}
```

One Scorecard per role per project. The platform creates it at project initialization and updates it incrementally — no full recomputation. Scorecard data is platform property; no vertical reads or writes it directly.

### 4.2 Role_Record

Location: `.shopfloor/object-model/Role_Record_[ROLE-ID].json` inside each project folder.

Per-role per-project activity record. The platform owns the schema envelope; the active vertical owns the `activityLog` payload.

**Platform envelope:**
```json
{
  "schemaVersion": "1.0",
  "roleId": "acquisitions-editor",
  "projectUUID": "1A2B3C4D-...",
  "dateCreated": "2026-04-14T09:00:00Z",
  "lastActive": "2026-04-14T18:00:00Z",
  "invocationCount": 12,
  "openFlags": [],
  "activityLog": []
}
```

`activityLog` — vertical-defined payload. Each entry is written by the role's skills and contains vertical-specific activity data (e.g., which entities were created, which content files were touched). Platform code never inspects `activityLog` contents.

`openFlags` — array of unresolved issues the role has raised. Structure is platform-defined (flagId, description, raisedAt, resolvedAt). Content is vertical-specific.

### 4.3 Team Manifest — Superseded

`team-manifest.json` (referenced in Storage Spec v1.0) is superseded by the Foreman architecture.

The Foreman reads `VERTICAL.md` and `global-registry.json` to know what is installed. `system-manifest.json` records `activeVertical`. Routing rules are defined in the active vertical's `ROLE.md` files and read by the Managing Editor (StoryEngine) or equivalent vertical coordinator. No separate team manifest file is needed.


### 4.4 Team Manifest (`team-manifest.json`) — Correction to v1.0

**`team-manifest.json` is NOT superseded.** It serves a purpose distinct from the global registry.

- **Global registry** — the employee file. What roles are installed and registered.
- **Team manifest** — the shift roster. Which roles are active and operational for this specific project.

These are different questions. A project may have a vertical with five roles registered, but only three activated. A role may be paused pending a scorecard review. The Foreman reads the team manifest to know who is on the floor right now — not just who could theoretically show up.

Location: `.shopfloor/team-manifest.json` inside each project folder. Written by the Foreman at project creation and updated when roles are activated, deactivated, or paused.

```json
{
  "schemaVersion": "1.0",
  "projectUUID": "1A2B3C4D-...",
  "activeVertical": "storyengine",
  "dateModified": "2026-04-14T18:00:00Z",
  "roles": {
    "acquisitions-editor":   { "status": "active",   "activatedAt": "2026-04-14T09:00:00Z" },
    "publisher":             { "status": "active",   "activatedAt": "2026-04-14T09:00:00Z" },
    "developmental-editor":  { "status": "active",   "activatedAt": "2026-04-14T09:00:00Z" },
    "proofreader":           { "status": "inactive", "activatedAt": null },
    "managing-editor":       { "status": "active",   "activatedAt": "2026-04-14T09:00:00Z" }
  }
}
```

`status` enum: `active` | `inactive` | `paused`. Platform-defined. Routing rules (which role handles Karen's request) are the vertical's responsibility — the Managing Editor or equivalent coordinator reads the team manifest to know who is available before routing.


---

## 5. Particle System

### 5.1 What a Particle Is

A particle is a tag on a file — not a separate data structure. When Karen promotes a file ("this might be something"), ShopFloor sets `isParticle: true` in the file's existing per-file metadata record. The file stays exactly where Karen put it. ShopFloor doesn't move it or copy it.

"Show me my particles" is a filtered view: all files where `isParticle: true`. A lens on existing files, not a separate data store.

### 5.2 Platform-Owned Particle Fields

These fields belong in the platform's per-file metadata record. They apply to any vertical — a legal writing vertical, a screenwriting vertical, or StoryEngine all use the same promotion mechanism.

```json
{
  "isParticle": true,
  "particleStatus": "raw",
  "captureMethod": "share_sheet",
  "sourceApp": "Safari",
  "sourceURL": "https://...",
  "sourceType": "",
  "lastSurfaced": null,
  "surfaceCount": 0
}
```

**`captureMethod`** — closed enum, controls processing logic:
- `share_sheet` — captured via iOS Share Sheet. Source app name auto-populated from Share Sheet metadata. Primary mobile capture path.
- `direct` — typed or spoken directly in-app
- `import` — pulled from external data source via structured extract
- `sync` — ingested from a connected vault or note system
- `manual` — pasted, dragged, or file-dropped via Files picker
- `promoted` — file already existed in Karen's notebooks; she elevated it to particle status

**`sourceApp`** — open string, provenance only. Auto-populated from Share Sheet bundle metadata for `share_sheet` captures. Never hardcode app names.

**`particleStatus`** — generic lifecycle state machine. Platform defines the states; vertical defines what progression means in their domain.

| Status | Generic meaning |
|--------|----------------|
| `raw` | Promoted but not yet engaged with |
| `considered` | Karen engaged — note added or connection made |
| `developing` | Actively being worked toward placement |
| `placed` | Incorporated into an active project |
| `shelved` | Intentionally set aside — retrievable |

Status advances are logged to the audit trail.

**`lastSurfaced` / `surfaceCount`** — resurfacing metrics for spaced repetition. Platform tracks these; the resurfacing schedule is platform-managed.

### 5.3 Particle Inbox

Particles with no project assignment go to a system-level Inbox. Platform-managed. No vertical-specific logic required — any unassigned particle lands here regardless of vertical.

### 5.4 Vertical-Owned Particle Extensions (StoryEngine declares these in `VERTICAL.md`)

These fields appear in StoryEngine's per-file metadata extension. They are not platform fields:
- `resonanceNote` — "what struck you?" free-text note at capture moment
- `linkedStartingLineup` — reference to a StoryEngine Starting_Lineup entity
- Entity chips at capture time (characters, scenes, wounds) — StoryEngine UI and data


---

## 6. Identity Architecture

Two identity systems serve two different masters. Neither replaces the other.

### 6.1 System 1 — UUIDs (Content File Identity)

**What:** Standard UUID v4. `8F3A2C1D-4B5E-6789-ABCD-EF0123456789`

**Used for:** Every content file Karen creates or controls — pages (`.md` files), books (folders). Anything Karen can rename, move, or delete.

**Why UUID:** Karen acts unpredictably. She renames chapters. She reorganizes notebooks. She deletes things she regrets. A UUID is opaque, permanent, and survives all of it. The human-readable filename is the display name. The UUID is the identity. They diverge freely.

**Who manages it:** ShopFloor assigns UUIDs at file birth. Karen never sees them. Verticals consume them but do not generate them.

**Where stored:**
- In the per-file metadata record (primary: `.shopfloor/files/[UUID-prefix].json`)
- In the project manifest `fileRegistry`
- In every object model record that references the file (`linkedFiles` or equivalent)

**Stability guarantee:** A UUID assigned at file birth is never changed. Not on rename. Not on move. Not on copy. Only on permanent deletion — and even then, the UUID is moved to `orphanRegistry` before the record is removed, preserving the audit trail.

### 6.2 System 2 — Entity IDs (Object Model Identity)

**What:** `[TYPE_PREFIX]-[ZERO_PADDED_5_DIGIT_SEQUENCE]`

Examples: `CHR-00001`, `SCN-00012`, `WND-00003`

**Used for:** Every object model record the system creates and manages — character profiles, scene containers, wounds, scorecards, role records. Anything Karen does not touch directly.

**Why not UUID:** Object model records are system-managed. Karen never opens, renames, or deletes them. A human-readable ID is safe here — and dramatically more useful. Audit logs, cross-references, debugging sessions, and conversations with Karen ("I updated CHR-00001") all benefit from legible IDs.

**Format specification (platform-defined):**
- Separator: `-` (hyphen)
- Sequence: always 5 zero-padded digits. Range: 00001–99999.
- TYPE_PREFIX: 2–4 uppercase letters, vertical-declared (see §6.4)
- Full format regex: `^[A-Z]{2,4}-[0-9]{5}$`

**Uniqueness scope:** Entity IDs are unique per type per project. `CHR-00001` in Project A and `CHR-00001` in Project B are different entities. Cross-project uniqueness is provided by combining entity ID with project UUID.

**Who manages sequence:** ShopFloor's `idCounters` in `manifest.json`. The counter stores the raw integer; formatting to 5-digit padded string happens at write time. The counter is incremented before the entity is written — no two entities in the same project receive the same sequence number for the same type.

### 6.3 The Bridge Between Systems

Content files (UUIDs) and object model entities (Entity IDs) are related but independent. The bridge is the `linkedEntities` array on the per-file metadata record.

```
Content file (UUID)  ←──→  Per-file metadata record
                               └── linkedEntities: ["CHR-00001", "SCN-00003"]
                                        │
                                        ↓
                               Object model records (Entity IDs)
                               Character_Profile_CHR-00001.json
                               Scene_Container_SCN-00003.json
```

Object model records may also carry references back to content files via UUID, but the per-file `linkedEntities` array is the authoritative bridge — it is what the app uses to display connections to Karen.

**Platform rule:** The bridge is maintained by the write-back contract (§3.3). When a skill creates an entity linked to a content file, it must update `linkedEntities` on the per-file record. When it creates an entity linked to another entity, it must update the cross-reference arrays on both records. No orphaned references.

### 6.4 Vertical Extension — Entity Type Prefixes

The platform defines the ID *format*. Verticals define the *type prefixes* for their entity types.

Declared in `VERTICAL.md` under `entity_types`:

```yaml
entity_types:
  - prefix: CHR
    name: Character_Profile
    description: "A character in the story"
  - prefix: SCN
    name: Scene_Container
    description: "A scene and its metadata"
  - prefix: WND
    name: Wound_Profile
    description: "A character's psychological wound"
```

The Foreman reads these declarations during vertical registration and initializes the corresponding `idCounters` entries in the project manifest at project creation: `{ "CHR": 0, "SCN": 0, "WND": 0 }`.

**Prefix rules (platform-enforced):**
- 2–4 uppercase letters
- Unique within the vertical
- Unique across all registered verticals (Foreman checks for conflicts at registration time — `ROLE_CONFLICT` equivalent for entity types)
- Reserved prefixes: none in v1.0, but the platform reserves the right to define system prefixes in future versions

**Leverageability:** A legal writing vertical might declare `CAS` (case), `PTY` (party), `DOC` (document). A screenwriting vertical might declare `SCN` (scene — conflicts with StoryEngine) and `CHR` (character — also conflicts). The Foreman's registration validation catches prefix conflicts before two verticals can coexist with overlapping type systems. In v1.0 with one vertical this is a non-issue; the architecture is ready for v2.

### 6.5 Object Model Directory

Location: `.shopfloor/object-model/` inside each project folder.

Container for all structured entities. Platform owns the directory and naming convention. Verticals own the contents.

**Naming convention:** `[EntityType]_[EntityID].json`
Examples: `Character_Profile_CHR-00001.json`, `Scorecard_acquisitions-editor.json`

**Platform entities** (present in every project regardless of vertical):
- `Scorecard_[role-id].json` — one per active role
- `Role_Record_[role-id].json` — one per active role

**Vertical entities** (declared by vertical, created by vertical's skills):
- Everything else in the directory

The platform never inspects the contents of vertical entity files. It reads filenames for the `objectModelRegistry` and that is all.


---

## 7. Orphan Detection and Repair

A file becomes orphaned when Karen renames, moves, or deletes it and the platform has not yet detected the change.

### 7.1 Detection

On session init, the Foreman's orphan-detection skill walks the project's `fileRegistry` and checks each recorded `relativePath` against the actual filesystem. Three cases:

| Observation | Action |
|-------------|--------|
| File exists at recorded path | No action needed |
| File missing at recorded path, but a file with same name exists elsewhere | Likely a move — update `relativePath` and `currentFilename` in per-file record |
| File missing, no match found | Mark UUID as orphaned — move to `orphanRegistry` in manifest |

### 7.2 Repair

**Rename/move detection:** The platform compares filename against all files in the project tree. If a unique filename match is found at a new path, the per-file record is silently updated. Karen never sees this happen.

**Orphan registry:** UUIDs with no recoverable file are moved to `manifest.orphanRegistry`. They are never deleted — the audit trail and any object model cross-references remain valid. If Karen later restores the file, the orphan can be re-linked by the orphan-manager skill.

**Platform rule:** No object model record is deleted because its linked content file was orphaned. The entity ID remains valid. The `linkedEntities` reference remains. Only the display path is marked unresolvable.


---

## 8. Context Indexing

### 8.1 The Problem

Skills have context budgets (8K / 10K / 12K tokens by skill tier). Loading full schema files and full role definitions into every skill session would exhaust those budgets before any work gets done. The Skill Designer (flagged as Bottleneck 19.7) is the clearest example — it needs awareness of all available schemas and roles, but cannot load all of them in full.

### 8.2 Indexing as a Platform Capability

The platform defines **context indexing** as a general mechanism — not two specific files (`schema-index.json` and `role-index.json`) but a pattern any vertical can use for any resource type that skills need in compressed form.

**How it works:**
1. A vertical declares indexable resource types in `VERTICAL.md` under `indexes`
2. The Foreman generates an index file for each declared type at vertical registration
3. The index file is a compressed, context-budget-aware summary — field names, IDs, types — not full content
4. Skills declare which indexes they need in `contextFingerprint`
5. Session init loads only the declared indexes, not all of them

### 8.3 Index Declaration in `VERTICAL.md`

```yaml
indexes:
  - id: schema-index
    label: "Schema Index"
    sources: 
      - "Data Structures/Noun Data Structures/"
      - "Data Structures/Verb Data Structures/"
      - "Data Structures/Scaffolding/"
      - "Data Structures/Frameworks/"
    output: ".shopfloor/schema-index.json"
    format: compact         # compact | full
    invalidatedBy: sources  # regenerate when source files change

  - id: role-index
    label: "Role Index"
    sources:
      - "Roles/"
    output: ".shopfloor/role-index.json"
    format: compact
    invalidatedBy: sources
```

`format: compact` — the Foreman strips each source file to its essential identifiers: schema name, field names, field types, entity type prefix. No descriptions, no examples, no verbose documentation. The goal is a lookup table, not a reading experience.

### 8.4 Lazy Generation and Invalidation

Indexes are **not** regenerated on every session init. That would make the Foreman a bottleneck that precedes every skill execution.

Generation triggers:
- Vertical registration (first generation)
- Any source file changes since the index was last generated (detected by comparing `dateModified` of source files against index `generatedAt` timestamp)
- Explicit Foreman command (manual rebuild)

Session init checks `generatedAt` against source modification times. If stale, the Foreman regenerates before the skill loads. If current, the cached index is used directly.

### 8.5 Skill Declaration in `contextFingerprint`

A skill declares which indexes it needs:

```yaml
contextFingerprint:
  indexes:
    - schema-index
    - role-index
```

Session init loads only these. A skill that needs no indexes declares an empty list. A skill that needs only the role index loads only that. No skill loads all indexes by default.

### 8.6 Index File Format

Platform-defined envelope; vertical-defined content structure.

```json
{
  "indexId": "schema-index",
  "vertical": "storyengine",
  "generatedAt": "2026-04-14T18:00:00Z",
  "generatedBy": "foreman/index-builder",
  "entryCount": 49,
  "entries": [
    {
      "id": "Character_Profile",
      "typePrefix": "CHR",
      "fields": ["name", "age", "wound", "flaw", "want", "need"],
      "schemaVersion": "2.1"
    }
  ]
}
```

The `entries` array structure is defined by the vertical in `VERTICAL.md` under the index declaration (an optional `entrySchema` field). If no `entrySchema` is declared, the Foreman uses a default compact format: name + top-level field names only.


---

## 9. Safety and Escape Mechanisms

### 9.1 Platform Halt Signal

**Purpose:** An out-of-band emergency brake. When AI execution is misbehaving and Bill needs to stop it immediately — from any device, without editing configuration files, without Claude Code.

**Mechanism:** A file named `platform.halt` placed at the product root (sibling to project folders and `.shopfloor/`). Visible in the Files app on iOS. Creatable in seconds without any app.

```
StoryEngine/          ← product root
  platform.halt       ← halt signal (Bill creates this in emergency)
  .shopfloor/
  My Novel/
```

**Behavior when detected:**
- Platform overrides `productTier` to `0` for this session regardless of subscription
- No AI execution — all skills become human-readable only
- No writes to the object model
- No skill invocations
- Audit trail remains active (read-only platform operations continue)
- Karen's files are fully accessible — she can still read, write, and organize her content
- The app surfaces a minimal indicator to Bill (not to Karen) that halt mode is active

**Restoration:** Delete `platform.halt`. Next session init detects its absence and returns to normal operation. No configuration changes required.

**Design principles:**
- Creatable without Claude Code, without terminal, without any development tool
- Effective immediately on next session init — no restart required
- Invisible to Karen in effect (her experience degrades to Tier 0 silently)
- Self-documenting name — any developer finding this file knows what it does


---

## 10. Design Principles

These eight principles govern every architectural decision ShopFloor makes. They apply regardless of which vertical is installed. When in conflict, they are prioritized in the order listed.

### 10.1 Karen-Friendly and Karen-Proof
Karen will rename files. Karen will move chapters into new folders. Karen will delete things she regrets deleting. Karen will work on her iPhone at midnight and her MacBook in the morning. The platform must survive all of this without breaking, without losing data, and without requiring Karen to understand why anything happened.

### 10.2 No Roach Motel
Karen's content is hers. Every content file is plain markdown. If the product disappeared tomorrow, Karen would still have her manuscript. The object model — the structured intelligence the platform builds — is also exportable. A project-export skill (skill tier 1) can write the entire object model to human-readable markdown at any time. Karen is never trapped.

### 10.3 Self-Healing and Self-Repairing
The platform detects its own inconsistencies and repairs them silently or with minimal prompting. Orphaned metadata, broken references, renamed files, and UUID mismatches are handled gracefully. No error dialog ever says "database corrupted."

### 10.4 Desktop and Mobile Parity
The storage architecture must not create a two-class citizen problem. The file system is the canonical source of truth — not a local database — precisely because iCloud treats files as first-class citizens across all Apple devices. Platform decisions that would degrade the mobile experience require explicit justification.

### 10.5 Book and Page Metaphor
The folder is a book. The document is a page. These are the only two concepts Karen needs. Every implementation decision must map cleanly onto this metaphor.

### 10.6 Extensible — Rules First, Karen Later
Version 1: Bill writes skills and roles. The platform enforces them. Karen benefits without knowing they exist. Version 2+: Karen may extend or modify roles through conversation, not code. The platform architecture must accommodate this evolution without structural change.

### 10.7 Infrastructure is Invisible
No metadata files alongside content files. All infrastructure lives in `.shopfloor/`. The Notebooks App (Alfons Schmidt) anti-pattern — where every `.md` file has a visible sibling `.md.plist` — is the explicit failure mode this architecture avoids.

### 10.8 Organizational Clarity
Every skill belongs to a role. Every role has a job description in plain English. Every outcome is tracked. The Foreman knows who is on the floor, what they are doing, and how well they are performing. If you cannot explain who does what and how well they do it, the floor is not running right.

---

## 11. The Foreman

The Foreman is the platform's only role. It has no vertical-specific knowledge — it does not know what a character is, what a scene means, or how a novel is structured. It knows the platform.

**Responsibilities:**
- Vertical registration — reads `VERTICAL.md`, validates against the error taxonomy, writes to `global-registry.json`
- Team manifest management — initializes and updates the shift roster per project
- Context index generation — generates and invalidates compressed indexes declared by the vertical
- Session init orchestration — checks halt signal, loads system manifest, confirms team manifest, triggers stale index regeneration
- Halt detection — monitors for `platform.halt` at product root on every session init
- Global registry maintenance — the only writer to `~/.shopfloor/global-registry.json`

**What the Foreman is not:**
- Not a routing role. Routing Karen's conversation to the right vertical role is the vertical coordinator's job (StoryEngine's Managing Editor).
- Not a creative role. The Foreman has no opinions about story structure, legal arguments, or any vertical domain.
- Not Karen-facing. Karen never interacts with the Foreman directly.

**Location:** `Roles/foreman/ROLE.md` — a platform role, not a vertical role. Co-located with vertical roles in the `Roles/` directory but clearly marked as platform-layer in its ROLE.md header.

**Skills:** All Foreman skills are skill tier 1 (floor management). In v1.0, the first skill is `vertical-registration` (`Skills/system/vertical-registration/SKILL.md`). Additional skills (index-builder, orphan-manager, session-init, scorecard-updater) follow.

---

## 12. Skill Architecture Tiers

Three tiers classify every skill on the platform. The tier determines what kind of work the skill does, what context budget it receives, and which role owns it.

| Tier | Name | Context budget | Owns |
|------|------|---------------|------|
| 1 | Floor management | 8K tokens | Foreman |
| 2 | Quality control | 10K tokens | Platform rules roles (v1.0: TBD) |
| 3 | Production | 12K tokens | Vertical production roles |

**Tier 1 — Floor management:** Keeps the platform running. Invisible to Karen. Triggered by system events (session init, file change, skill invocation), not by Karen's conversation. Examples: vertical-registration, orphan-manager, index-builder, scorecard-updater.

**Tier 2 — Quality control:** Evaluation and gate enforcement. Triggered by workflow state transitions. May surface findings to Karen as part of a role's output, but Karen does not invoke them directly. Examples (StoryEngine): character-arc-checker, continuity-checker, conformance-reporter.

**Tier 3 — Production:** Direct value delivery. Triggered by Karen's conversation with a role. These are the skills Karen experiences, even if she doesn't know they're running. Examples (StoryEngine): starting-lineup, greenlight-review, character-creation, scene-development.

**Skill tier applies across all verticals.** A StoryEngine Tier 3 skill and a future GameEngine Tier 3 skill operate under the same context budget and ownership rules. The tier is a platform classification; the vertical provides the content.


---

## 13. Vertical Registration Contract

### 13.1 Overview

Every vertical that integrates with ShopFloor provides a `VERTICAL.md` file at the repo root. This is the vertical's formal declaration — the single artifact the Foreman reads to know what is installed and what it provides.

The contract format is platform-defined. The content is vertical-provided.

### 13.2 `VERTICAL.md` Field Schema

**Required fields:** `name`, `vertical_id`, `version`, `roles` (at least one), `skills` (at least one), `product_tier_compatibility` (at least one value).

```yaml
name: storyengine                    # Human-readable name
display_name: StoryEngine            # Display name in UI
version: "1.0"
description: "Fiction writing intelligence vertical for ShopFloor"
vertical_id: storyengine             # Slug — primary key in global-registry.json
maintainer: bill

roles:
  - id: acquisitions-editor
    path: Roles/acquisitions-editor/ROLE.md
  - id: publisher
    path: Roles/publisher/ROLE.md
  - id: developmental-editor
    path: Roles/developmental-editor/ROLE.md
  - id: proofreader
    path: Roles/proofreader/ROLE.md
  - id: managing-editor
    path: Roles/managing-editor/ROLE.md

skills:
  - id: starting-lineup
    path: Skills/creative/starting-lineup/SKILL.md
    skill_tier: 3
    role: acquisitions-editor
  - id: greenlight-review
    path: Skills/creative/greenlight-review/SKILL.md
    skill_tier: 3
    role: publisher
  - id: skill-designer
    path: Skills/creative/skill-designer/SKILL.md
    skill_tier: 3
    role: managing-editor

entity_types:
  - prefix: CHR
    name: Character_Profile
  - prefix: SCN
    name: Scene_Container
  - prefix: WND
    name: Wound_Profile

schema_paths:
  - Data Structures/Noun Data Structures/
  - Data Structures/Verb Data Structures/
  - Data Structures/Scaffolding/
  - Data Structures/Frameworks/

indexes:
  - id: schema-index
    sources:
      - Data Structures/Noun Data Structures/
      - Data Structures/Verb Data Structures/
      - Data Structures/Scaffolding/
      - Data Structures/Frameworks/
    output: .shopfloor/schema-index.json
    format: compact
    invalidatedBy: sources
  - id: role-index
    sources:
      - Roles/
    output: .shopfloor/role-index.json
    format: compact
    invalidatedBy: sources

per_file_extensions:
  - field: storyengine_isParticle
    type: boolean
    default: false
  - field: storyengine_particleStatus
    type: string
    enum: [raw, considered, developing, placed, shelved]
  - field: storyengine_resonanceNote
    type: string
  - field: storyengine_linkedStartingLineup
    type: string

product_tier_compatibility: [0, 1, 2]
data_directory: storyengine
```

Note: `skill_tier` refers to the skill architecture tier (1/2/3). `product_tier_compatibility` refers to the product tier (0/1/2). Field names are intentionally distinct.

### 13.3 Foreman Validation — Error Taxonomy

The Foreman checks every `VERTICAL.md` against this taxonomy at registration. Registration is atomic — any Fail-level error prevents any write to the global registry.

| Code | Condition | Severity |
|------|-----------|----------|
| `MISSING_REQUIRED_FIELD` | A required field is absent | Fail |
| `INVALID_TIER_VALUE` | `product_tier_compatibility` contains a value outside [0,1,2] | Fail |
| `DUPLICATE_VERTICAL` | A vertical with this `vertical_id` already exists in global-registry.json | Fail |
| `PATH_NOT_FOUND` | A declared role, skill, or schema_path does not exist in the repo | Fail |
| `ENTITY_PREFIX_CONFLICT` | An entity type prefix conflicts with one already registered by another vertical | Fail |
| `FIELD_NAME_CONFLICT` | A `per_file_extensions` field name conflicts with a platform-reserved field or another vertical's extension | Fail |
| `UNKNOWN_SKILL_TIER` | A skill's `skill_tier` is not 1, 2, or 3 | Fail |
| `SCHEMA_PATH_OVERLAP` | A `schema_path` is already claimed by another vertical | Warning — log, do not block |

All errors are appended to `.shopfloor/audit-trail.jsonl` as structured entries. At product Tier 0 (Bill executing manually), errors are also printed as a numbered list.

### 13.4 Vertical Registration Sequence

When the Foreman's `vertical-registration` skill runs:

1. Read `VERTICAL.md` from repo root
2. Validate all fields against error taxonomy — halt on any Fail-level error
3. Initialize `idCounters` entries in project manifest for each declared entity type prefix
4. Write vertical entry to `~/.shopfloor/global-registry.json`
5. Generate all declared indexes (see §8)
6. Log `VERTICAL_REGISTERED` event to audit trail
7. **Verification step (mandatory):** Open `global-registry.json` and confirm the new vertical entry is present and all declared paths resolve

At product Tier 0: Bill performs each step manually following the SKILL.md. The verification step is a hard requirement — not optional.

---

## 14. Self-Healing File Reconciliation

On session init, the Foreman's orphan-detection skill reconciles the recorded file registry against the actual filesystem. The vertical has no role in this process.

**Detection sequence:**
1. Walk `manifest.fileRegistry` — one entry per tracked file
2. For each entry, check `relativePath` against the filesystem
3. Classify each file: present at path / moved (filename found elsewhere) / missing

**Repair actions:**

| Classification | Action |
|---------------|--------|
| Present at recorded path | No action |
| Filename found at new path | Update `relativePath` and `currentFilename` in per-file record. Log `FILE_MOVED` to audit. Silent — Karen never sees this. |
| Filename not found anywhere | Mark UUID as `orphaned` in per-file record. Move to `manifest.orphanRegistry`. Log `FILE_ORPHANED` to audit. |

**Orphan preservation:** Orphaned UUIDs are never deleted. Entity IDs that reference an orphaned file UUID remain valid — the cross-reference is preserved even if the file is gone. If Karen restores the file, the orphan-manager skill can re-link it.

**Platform guarantee:** No object model record is deleted because its linked content file was orphaned. The entity ID remains valid. Only the display path becomes unresolvable.


---

## 15. Skill Warranty System

### 15.1 Warranty Complete Event

`SKILL_WARRANTY_COMPLETE` is recorded when a skill's invocation count reaches the warranty target. It marks the end of the initial evaluation period and triggers an automated verdict.

```json
{
  "event": "SKILL_WARRANTY_COMPLETE",
  "timestamp": "2026-04-20T14:22:00Z",
  "skillId": "character-creation",
  "skillVersion": "1.0",
  "role": "dev-editor",
  "sessionId": "SES-0042",
  "warrantyInvocations": 10,
  "acceptanceRate": 0.80,
  "modificationRate": 0.20,
  "ignoredRate": 0.00,
  "verdict": "graduated | flagged",
  "transitionedTo": "active | under_review"
}
```

**`verdict`:**
- `graduated` — acceptance rate met or exceeded the quality threshold; skill moves to default post-warranty evaluation mode
- `flagged` — acceptance rate fell below threshold; skill is marked `under_review`; Bill is notified; Karen is not interrupted

**`transitionedTo`:**
- `active` — normal post-warranty operation; Karen may be prompted occasionally per the `active` frequency setting
- `under_review` — skill remains usable but is flagged for Bill's attention; the Skill Designer's "improve existing" flow is the appropriate next step

Quality threshold defaults live in `system-manifest.json` under `quality_control`. The platform evaluates the verdict automatically — no human decision required at warranty end unless the skill is flagged.

### 15.2 Outcome Detection

**Entity-creating skills:** Acceptance is implicit. If the write-back ran and the entity exists, the outcome is `accepted`.

**Advisory skills** (suggestions, analysis, no entity written): The app tracks whether Karen acted on the result within the session. Session ends without action → `ignored`. Karen confirms → `accepted`. Karen confirms with changes → `modified`.

All three outcome types feed the Scorecard. `SKILL_OUTCOME` drives quantitative metrics. `SKILL_FEEDBACK` provides qualitative signal. `SKILL_WARRANTY_COMPLETE` marks phase transitions.

---

## 16. Schema Versioning and Migration

### 16.1 Every Record is Versioned

Every JSON record — per-file metadata, container manifest, and object model records — carries two version fields:

```json
{
  "schemaVersion": "1.0",
  "profileVersion": 2
}
```

`schemaVersion` — which template version created this record. String (e.g., `"2.1"`). Set at creation, updated on migration.

`profileVersion` — how many times this specific record was updated. Integer, starting at 1, incremented by the write-back contract on every update. Never resets.

When a skill reads a record whose `schemaVersion` does not match the current template version, it triggers migration.

### 16.2 Migration Sequence

1. Read the old record
2. Create a new record from the current template
3. Map old fields to new fields where names match exactly
4. Flag new required fields that have no mapping as `"[MIGRATION-NEEDED]"`
5. Write the new record (overwrite in place)
6. Archive the old record to `.shopfloor/snapshots/[date]_[filename]`
7. Log `SCHEMA_MIGRATED` to the audit trail with old and new `schemaVersion`

No data is ever deleted during migration. The archive is always available in snapshots. `[MIGRATION-NEEDED]` flags are visible to the next skill that reads the record — it handles completion as part of its normal workflow.

---

## 17. iCloud Sync and Conflict Resolution

### 17.1 Governing Principle

Last-write-wins. iCloud Drive handles file-level conflicts using this policy with automatic versioning. When two devices write the same file simultaneously, iCloud creates a conflict copy (e.g., `manifest (Bill's MacBook's conflicted copy).json`).

ShopFloor matches Apple's policy: most recently modified file wins. Conflict copies are moved to `.shopfloor/snapshots/` for review — never silently deleted.

### 17.2 Why This Works

Alfons Schmidt has shipped Notebooks App with this exact iCloud architecture for over a decade, with hundreds of thousands of users across iPhone, iPad, and Mac simultaneously. File-level conflicts severe enough to cause data loss are essentially nonexistent in practice. The architecture is battle-tested.

### 17.3 Rename Lag

The realistic sync risk is rename lag: Karen renames a chapter on iPhone. Before iCloud syncs, she opens her Mac and the chapter still shows the old name. This is a display inconsistency, not a data loss event. The UUID layer means the underlying object model stays correct — only the display name is temporarily stale. Self-healing reconciliation (§14) corrects it at next session init.

### 17.4 Write Serialization

ShopFloor skills write to `.shopfloor/` serially within a session. No parallel writes from Claude within the same conversation. The concurrency risk is device-to-device, which iCloud handles. Platform code does not implement its own locking — the idCounters increment-before-write pattern (§6.2) is sufficient for within-session safety.

### 17.5 Failure Modes

| Failure | Consequence | Recovery |
|---------|-------------|----------|
| Write succeeds, manifest update fails | Entity exists but unregistered | Session-init scans `object-model/` for unregistered records and registers them |
| Cross-reference update fails | One-sided link | Session-init `BROKEN_XREF` scan detects and repairs |
| ID counter write fails | Possible duplicate ID on next session | Collision detected at write time; increment and retry |
| Complete write failure (disk full, iCloud conflict) | No entity created | Skill reports failure to Karen; conversation data preserved for retry |
| Manifest missing entirely | No `manifest.json` in `.shopfloor/` | Cold-start reconstruction: scan all metadata records in `files/`, rebuild manifest, log `MANIFEST_RECONSTRUCTED` |

No partial state is ever silently accepted. Every failure is logged and flagged for repair.


---

## 18. Platform / Vertical Boundary

This section is the authoritative statement of what belongs to ShopFloor and what belongs to the vertical. When in doubt, apply the governing principle: **subject matter expertise is the domain of the vertical.**

### 18.1 ShopFloor Owns

| Concept | Location |
|---------|----------|
| Hidden directory convention (`.shopfloor/`) | §1.1 |
| UUID generation and assignment | §1.2 |
| Per-file metadata base schema | §1.3 |
| Container manifest structure | §1.4 |
| Audit trail mechanism and platform event types | §1.5 |
| Snapshots and versioning | §1.6 |
| Global skill registry | §2.1 |
| Per-project skill registry structure | §2.2 |
| Skill evaluation modes (warranty / active / passive) | §2.3 |
| System manifest | §3.1 |
| Session state envelope | §3.2 |
| Write-back contract (sequence) | §3.3 |
| Scorecard mechanism and schema | §4.1 |
| Role_Record envelope | §4.2 |
| Team manifest (shift roster) | §4.4 |
| Particle promotion flag and base fields | §5.2 |
| Particle Inbox | §5.3 |
| Object model directory and naming convention | §6.5 |
| Entity ID format (`[PREFIX]-[5-digit-sequence]`) | §6.2 |
| UUID ↔ Entity ID bridge mechanism | §6.3 |
| Entity type prefix rules (platform enforces, vertical declares) | §6.4 |
| Orphan detection and repair | §7 / §14 |
| Context indexing mechanism | §8 |
| Platform halt signal (`platform.halt`) | §9.1 |
| Design principles | §10 |
| Foreman role | §11 |
| Skill architecture tiers (1/2/3) | §12 |
| Vertical registration contract format and error taxonomy | §13 |
| Self-healing file reconciliation | §14 |
| Skill warranty system | §15 |
| Schema versioning and migration sequence | §16 |
| iCloud sync policy | §17 |

### 18.2 The Vertical Owns

ShopFloor has no knowledge of the following. They belong in the StoryEngine Spec (or the equivalent spec for any vertical).

| Concept | Belongs in |
|---------|-----------|
| All Noun data structures (Character_Profile, Location_Profile, Scene_Container, Wound_Profile, etc.) | StoryEngine Spec |
| All Verb data structures (Arc_Beat_Sheet, Plot_Thread_Tracker, Scene_Inventory, etc.) | StoryEngine Spec |
| All Scaffolding (Story_Spine, Conformance_Report, Thread_Registry, etc.) | StoryEngine Spec |
| Frameworks (Three-Act, Save the Cat, Seven-Point, Story Grid, Hero's Journey) | StoryEngine Spec |
| Starting_Lineup schema | StoryEngine Spec |
| Five production roles (Acquisitions Editor, Publisher, Developmental Editor, Proofreader, Managing Editor) | StoryEngine Spec |
| Role routing rules (which role handles which conversation state) | StoryEngine Spec / Managing Editor ROLE.md |
| Particle vertical extensions (resonanceNote, linkedStartingLineup) | StoryEngine Spec |
| Two-layer capture sheet UI (entity chips for characters, scenes, wounds) | StoryEngine Spec |
| Fiction-specific skills (starting-lineup, greenlight-review, character-creation, etc.) | StoryEngine Spec / individual SKILL.md files |
| `particleStatus` lifecycle meaning (what "developing" means in fiction context) | StoryEngine Spec |
| Entity type prefixes (CHR, SCN, WND, etc.) | StoryEngine `VERTICAL.md` |
| Object model record contents | StoryEngine Spec |
| Session state `state` payload | StoryEngine Spec |
| Role_Record `activityLog` payload | StoryEngine Spec |
| Index entry structure (beyond platform envelope) | StoryEngine `VERTICAL.md` |

### 18.3 The Seam

The seam between platform and vertical runs through four artifacts:

1. **`VERTICAL.md`** — the contract. Vertical declares what it provides. Platform validates and registers it.
2. **Per-file metadata record** — platform owns base fields. Vertical declares extensions in `VERTICAL.md` under `per_file_extensions`.
3. **Session state** — platform owns the envelope. Vertical owns `state` payload.
4. **Role_Record** — platform owns the envelope. Vertical owns `activityLog` payload.

Nothing crosses the seam without a formal declaration. The Foreman enforces this at registration time.

---

*End of ShopFloor Platform Specification v1.0*
*Derived from ShopFloor Storage Spec v1.0 via concept-assignment session 2026-04-14*
*Next: StoryEngine Spec — all vertical concepts listed in §18.2*


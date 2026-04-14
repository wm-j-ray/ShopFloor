# ShopFloor — Storage Architecture Specification
**Version:** 1.0 (Design Phase)  
**Status:** Pre-implementation — Claude Code handoff ready  
**Author:** Bill (architecture), Claude (documentation)  
**Date:** 2026-04-12  
**Classification:** Foundational. All skill design, role design, object model design, and app design depend on decisions made here.

---

## 1. Executive Summary

**ShopFloor** is a storage and skill orchestration platform. It manages files, identity, structured data, roles, skills, quality control, and audit — the invisible infrastructure that makes an AI-powered creative tool work.

ShopFloor is **vertical-agnostic.** It does not know what kind of work it supports. It provides the floor. The vertical provides the team.

The first vertical built on ShopFloor is **StoryEngine** — a Claude-powered writing intelligence system for fiction authors. StoryEngine installs a team of roles (Developmental Editor, Copy Editor, Continuity Guard, Story Keeper) onto the ShopFloor platform. Each role has responsibilities. Each responsibility is fulfilled by one or more skills. A different vertical — legal writing, screenwriting, academic research — would install a different team with different roles and different skills. The floor stays the same.

This document specifies the ShopFloor platform layer only. Vertical-specific design (which roles exist, which skills they carry, which data structures they use) is out of scope but depends on the decisions made here.

**Two metaphors govern this document:**

1. **The iceberg.** Karen sees what is above the waterline — her books, her pages, her conversations. Everything below is managed, versioned, and protected by ShopFloor.

2. **The shop floor.** The system's work is organized like a well-run production floor. Roles work at stations. Each station has the tools (skills) and materials (context) it needs. Floor management keeps everything running. Quality control tracks what's working and what isn't.

---

## 2. Design Principles (Non-Negotiable)

These eight principles govern every architectural decision in this document. When in conflict, they are prioritized in the order listed.

### 2.1 Karen-Friendly and Karen-Proof
Karen will rename files. Karen will move chapters into new folders. Karen will delete things she regrets deleting. Karen will work on her iPhone at midnight and her MacBook in the morning. The system must survive all of this without breaking, without losing data, and without requiring Karen to understand why anything happened.

### 2.2 No Roach Motel
Karen's content is hers. She can open it in any text editor, move it to Scrivener, email it to her agent, or print it. There is no proprietary lock-in. Every content file is plain markdown. If the product disappeared tomorrow, Karen would still have her manuscript.

This principle extends to the object model. The structured intelligence the system builds — character profiles, wound analyses, conformance reports — is also Karen's. A project-export skill (Tier 1, see Section 15.1) can write the entire object model to human-readable markdown at any time. Karen is never trapped.

### 2.3 Self-Healing and Self-Repairing
The system detects its own inconsistencies and repairs them silently or with minimal prompting. Orphaned metadata, broken references, renamed files, and UUID mismatches are handled gracefully. No error dialog ever says "database corrupted."

### 2.4 Reduce Impedance Mismatch Between Desktop and Mobile
The storage architecture must not create a two-class citizen problem where desktop users have full capability and mobile users are degraded. The file system is the canonical source of truth, not a local database, precisely because iCloud treats files as first-class citizens across all Apple devices.

### 2.5 Book and Page Metaphor
The folder is a book. The document is a page. These are the only two concepts Karen needs. Every implementation decision must map cleanly onto this metaphor.

### 2.6 Extensible — Rules First, Karen Later
Version 1: Bill writes the rules (as skills, organized into roles). The system enforces them. Karen benefits without knowing they exist. Version 2+: Karen may be able to extend or modify roles through conversation, not code. She says what she needs; the Skill Designer handles the rest. The architecture must accommodate this evolution without structural change.

### 2.7 Infrastructure is Invisible
No metadata files alongside content files. No `.DS_Store`-style pollution in Karen's view of her work. All infrastructure lives in hidden directories (`.shopfloor/`) by convention. The Notebooks App (Alfons Schmidt) problem — where every `.md` file has a sibling `.md.plist` file visible in Finder — is the explicit anti-pattern this architecture avoids.

### 2.8 Organizational Clarity
The system's work is organized into roles with clear responsibilities, measurable outcomes, and traceable history. Every skill belongs to a role. Every role has a job description written in plain English. Every outcome is tracked. If you can't explain who does what and how well they do it, the floor isn't running right.

---

## 3. Reference: The Notebooks App Problem

**Notebooks App** (by Alfons Schmidt, https://www.notebooksapp.com) is the closest existing product to the user experience ShopFloor supports. It uses a clean book/page metaphor, exposes the file system natively, and supports "Reveal in Finder" so users always know where their files live.

Notebooks uses plist files for metadata — one `BookProperties.plist` at the container (folder) level and one `[filename].plist` sibling file for each document. This architecture is:

- **Bullet-proof**: Plists are plain XML, human-readable, iCloud-safe, crash-tolerant.
- **Well-understood**: Apple's own apps have used this pattern for decades.
- **The source of ongoing user grief**: The plist files appear alongside content files in Finder. Users see `Chapter One.md` and `Chapter One.md.plist` side by side. The `.plist` files feel like litter. Alfons gets community complaints about this regularly.

The lesson: **the metadata-alongside-content approach is architecturally correct. The placement is wrong.**

ShopFloor adopts the per-file metadata approach but makes two changes: it relocates all infrastructure to a hidden directory (solving the visibility problem), and it uses JSON instead of plist (optimizing for AI readability — Claude reads and generates JSON natively, and JSON is more compact, more diffable, and equally iCloud-safe).

---

## 4. File System Architecture

### 4.1 The Core Convention

```
iCloud Drive/
  StoryEngine/                        <- PRODUCT ROOT (vertical-specific name)
    My Novel/                         <- BOOK (folder, Karen-visible)
      Chapter One.md                  <- PAGE (Karen-visible, Karen-owned)
      Chapter Two.md                  <- PAGE (Karen-visible, Karen-owned)
      The Ending.md                   <- PAGE (Karen-visible, Karen-owned)
      Characters/                     <- BOOK (nested, Karen-visible)
        Echo Bullard.md               <- PAGE (Karen-visible, Karen-owned)
        Jack Bullard.md               <- PAGE (Karen-visible, Karen-owned)
      .shopfloor/                     <- HIDDEN (dot-prefix, Karen-invisible)
        manifest.json                 <- Container metadata and UUID registry
        session-state.json            <- Last session context for resumption
        files/                        <- Per-file metadata (keyed by UUID)
          8F3A2C1D.json              <- Chapter One.md
          7E2B1A0C.json              <- Chapter Two.md
          6D1A0B9F.json              <- The Ending.md
          5C0F9E8D.json              <- Echo Bullard.md
          4B9E8D7C.json              <- Jack Bullard.md
        object-model/                 <- Story intelligence layer
          Character_Profile_CHR001.json
          Character_Profile_CHR002.json
          Scene_Inventory.json
          Story_Spine.json
          Thread_Registry.json
          Conformance_Report.json
          Role_Record_DEV_EDITOR.json
          Role_Record_COPY_EDITOR.json
          Scorecard_DEV_EDITOR.json
          Scorecard_COPY_EDITOR.json
        audit/                        <- Audit trail (append-only)
          audit.jsonl
        snapshots/                    <- Versioned backups
          2026-04-11_manifest.json
        skills/                       <- Skills that govern this project
          skill-registry.json
```

**Product root folder:** The top-level folder in iCloud Drive carries the vertical's product name (e.g., `StoryEngine/` for fiction). Different verticals use different names. Karen sees this folder as her product's home. ShopFloor never appears in any path Karen can see.

### 4.2 The System Root

The product root folder also contains the system-level ShopFloor infrastructure — the global skill library, role definitions, team manifest, and framework templates:

```
StoryEngine/
  .shopfloor/
    system-manifest.json          <- Runtime state + quality control thresholds (active_project_count, etc.)
    team-manifest.json            <- Team definition: installed roles, routing rules, skill assignments
    schema-index.json             <- Compact schema summary for Skill Designer (regenerated by schema-migrator)
    role-index.json               <- Compact role summary for Skill Designer (regenerated by session-init)
    skill-registry.json           <- Registry of all installed and pending skills
    roles/                        <- Role definitions (ROLE.md files)
      acquisitions-editor/
        ROLE.md
      publisher/
        ROLE.md
      developmental-editor/
        ROLE.md
      proofreader/
        ROLE.md
      managing-editor/
        ROLE.md
    frameworks/                   <- Read-only framework templates
      three-act.json
      save-the-cat.json
      seven-point.json
      story-grid.json
      heros-journey.json
    skills/                       <- Bill's skills, available to all projects
      system/                     <- Tier 1 — floor management
        session-init/SKILL.md
        orphan-manager/SKILL.md
        schema-migrator/SKILL.md
        backup-restore/SKILL.md
        project-export/SKILL.md
        skill-installer/SKILL.md
        routing/SKILL.md
        scorecard-updater/SKILL.md
      rules/                      <- Tier 2 — quality control
        character-arc-checker/SKILL.md
        timeline-validator/SKILL.md
        continuity-checker/SKILL.md
        conformance-reporter/SKILL.md
        thread-drift-detector/SKILL.md
      creative/                   <- Tier 3 — production stations
        character-creation/SKILL.md
        conflict-management/SKILL.md
        scene-development/SKILL.md
        voice-profiler/SKILL.md
        skill-designer/SKILL.md
      pending/                    <- Skills awaiting installation
        [any SKILL.md files drafted on mobile]
  [Project folders live here as siblings]
  My Novel/
  KILLSWITCH/
```

### 4.3 Visibility Rules

| Location | Visible to Karen? | Owned by |
|---|---|---|
| Any `.md` file | Yes | Karen |
| Any folder without dot-prefix | Yes | Karen |
| `.shopfloor/` | No (hidden by convention) | ShopFloor |
| `manifest.json` (inside `.shopfloor/`) | No | ShopFloor |
| `files/` (inside `.shopfloor/`) | No | ShopFloor |
| `object-model/` (inside `.shopfloor/`) | No | ShopFloor |
| `roles/` (inside `.shopfloor/`) | No | ShopFloor |
| `skills/` (inside `.shopfloor/`) | No | ShopFloor |

**Hidden directory behavior:** On macOS and iOS, any file or folder prefixed with `.` (period) is hidden from Finder, Files app, and most file browser UIs by default. A technical user can reveal hidden files (`Cmd+Shift+.` in Finder), but a typical Karen never will.

---

## 5. Identity Architecture — The UUID Layer

### 5.1 The Problem Karen Creates

Karen renames `Chapter One.md` to `The Beginning.md`. Every internal reference that used `Chapter One.md` as a key is now broken. The Scene Inventory references this file. The Character Profile references scenes in this file. The audit log references it. Without a UUID layer, a rename cascades into a consistency failure.

### 5.2 The Solution: UUIDs Are Assigned at Birth, Never Change

When a file is created — by Karen or by the system — ShopFloor assigns it a UUID immediately. This UUID is stored in:

1. The file's metadata record in `.shopfloor/files/`
2. The project `manifest.json`
3. Every object-model record that references this file

The human-readable filename is the *display name*. The UUID is the *identity*. They can diverge freely.

### 5.3 Per-File Metadata — JSON Structure

Per-file metadata records are stored in `.shopfloor/files/` and named by the first 8 characters of the UUID (e.g., `8F3A2C1D.json`). This avoids filename collisions when Karen has identically-named files in different subdirectories.

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
  "linkedEntities": ["SCN-001", "SCN-002", "SCN-003"],
  "status": "active"
}
```

**Field notes:**
- `relativePath`: path relative to the project root (e.g., `Characters/Echo Bullard.md` for a file in a nested book). Used by the orphan scan to locate files without a full tree search.
- `linkedEntities`: entity IDs (e.g., `SCN-001`, `CHR-002`) linking this content file to object model records. These are short IDs matching the object model naming convention, not UUIDs (see Section 5.4).

### 5.4 The Two Identity Systems

ShopFloor uses two identity systems for two different purposes:

| System | Format | Used for | Example |
|---|---|---|---|
| **UUIDs** | Standard 36-character UUID | Content files Karen creates (chapters, character pages) | `8F3A2C1D-4B5E-6789-ABCD-EF0123456789` |
| **Entity IDs** | `[TYPE]-[SEQ]` (short, human-readable) | Object model records the system creates (profiles, inventories, tags) | `CHR-001`, `SCN-012`, `PRT-00047` |

**Why two systems?** Content files need UUIDs because Karen controls them — she renames, moves, and deletes them unpredictably. The UUID survives all of that. Object model records are system-managed — Karen never touches them directly — so a human-readable ID is safe and far more useful in audit logs, cross-references, and debugging.

**The bridge between them:** The `linkedEntities` array in a per-file record connects a content file (UUID) to its object model records (entity IDs). The `objectModelRegistry` in the manifest lists every entity ID in the project. Entity IDs are the primary key for the object model — they are lookup keys, not just display labels.

### 5.5 Container Manifest — JSON Structure (manifest.json)

The manifest is the table of contents for a project. It tracks every content file (by UUID) and every object model entity (by entity ID), along with the ID counters used during write-back (Section 7).

```json
{
  "containerUUID": "1A2B3C4D-5E6F-7890-ABCD-EF0123456789",
  "containerName": "My Novel",
  "schemaVersion": "1.0",
  "dateCreated": "2026-04-01T09:00:00Z",
  "dateModified": "2026-04-11T16:45:00Z",
  "shopfloorVersion": "1.0.0",
  "activeFramework": "three-act",
  "activeTeam": "storyengine-fiction",
  "fileRegistry": [
    {
      "uuid": "8F3A2C1D-4B5E-6789-ABCD-EF0123456789",
      "currentFilename": "Chapter One.md",
      "relativePath": "Chapter One.md",
      "type": "page",
      "status": "active"
    }
  ],
  "idCounters": {
    "CHR": 2,
    "SCN": 0,
    "WND": 0,
    "PRT": 0
  },
  "objectModelRegistry": [
    {
      "entityID": "CHR-001",
      "entityType": "Character_Profile",
      "schemaVersion": "2.1",
      "dateCreated": "2026-04-11T14:23:00Z"
    }
  ],
  "orphanRegistry": []
}
```

---

## 6. The Object Model Layer

### 6.1 Overview

The project's intelligence lives in the `object-model/` subdirectory inside `.shopfloor/`. This is Karen's story (or brief, or screenplay), machine-readable. It is built and maintained by skills — never directly by Karen.

The object model is organized into five categories: Nouns, Verbs, Scaffolding, Frameworks, and Operations.

### 6.2 Noun Data Structures (Entities)

These are the things that exist in Karen's story. Each is a JSON record instantiated from a template when Karen (via conversation) creates that entity.

| Data Structure | Template Version | File Pattern |
|---|---|---|
| Character_Profile | 2.1 | `Character_Profile_CHR001.json` |
| Location_Profile | 2.1 | `Location_Profile_LOC001.json` |
| Scene_Container | current | `Scene_Container_SCN001.json` |
| Relationship_Profile | current | `Relationship_Profile_REL001.json` |
| Group_Profile | current | `Group_Profile_GRP001.json` |
| Event_Profile | current | `Event_Profile_EVT001.json` |
| Timeline_Entry | current | `Timeline_Entry_TML001.json` |
| Object_Profile | current | `Object_Profile_OBJ001.json` |
| Region_Profile | current | `Region_Profile_RGN001.json` |
| POV_Profile | current | `POV_Profile_POV001.json` |
| Narrator_Profile | current | `Narrator_Profile_NAR001.json` |
| Voice_Profile | current | `Voice_Profile_VOC001.json` |
| Theme_Statement | current | `Theme_Statement_THM001.json` |
| Wound_Profile | current | `Wound_Profile_WND001.json` |
| Wound_Tag | current | `Wound_Tag_WTG001.json` |
| Conflict_Tag | current | `Conflict_Tag_CFT001.json` |
| Motif_Profile | current | `Motif_Profile_MOT001.json` |
| Era_Profile | current | `Era_Profile_ERA001.json` |
| Starting_Lineup | 1.1 | `Starting_Lineup_SLU001.json` |

### 6.2.1 Particle Storage — A Special Case

**A particle is a tag on a file.** Not a separate data structure. Not a JSON record in `object-model/`. When Karen promotes a file by saying "this might be something," ShopFloor sets `isParticle: true` in the file's existing per-file metadata record in `.shopfloor/files/[UUID].json`. The file stays exactly where Karen put it — her inbox notebook, her cybercrime notebook, wherever. ShopFloor doesn't move it or copy it. It just notes: *this file has been elevated.*

**"Show me my particles"** is a filtered view. Show all files where `isParticle: true`. A lens on existing files, not a separate data store.

This eliminates:
- The `Particle_PRT00001.json` pattern in `object-model/`
- The `PRT` counter in idCounters
- The Particle as a separate schema entity

**Particle fields live in** `.shopfloor/files/[UUID].json` — the per-file metadata record that already exists for every file (see Section 5.2). When Karen promotes a file, particle-specific fields are added to that record:

```json
{
  "uuid": "8F3A2C1D...",
  "currentFilename": "swatting-nyc.md",
  "relativePath": "Cybercrime/swatting-nyc.md",
  "isParticle": true,
  "particleStatus": "raw",
  "resonanceNote": "",
  "captureMethod": "share_sheet",
  "sourceApp": "Safari",
  "sourceURL": "",
  "sourceType": "",
  "linkedEntities": [],
  "linkedStartingLineup": "",
  "lastSurfaced": "",
  "surfaceCount": 0
}
```

**File protection:** Karen is fully protected when she renames or moves files. The UUID never changes. The per-file metadata record updates `currentFilename` and `relativePath` automatically via the self-healing rename detection system (Section 11). The particle tag follows the file silently.

**This is NOT a macOS tag.** Nothing to do with Finder colored labels. `isParticle` is a field in a hidden JSON file Karen never sees.

### The Capture Philosophy

**Capture is instant. Classification is deferred. But the line between them is porous at the moment of capture.**

Karen should never have to decide what a particle *means* before she can save it. She captures it because it matters. What it connects to in the story gets worked out later. But there is a moment — right at capture, when Karen just saw the thing and her mind is alive with why it struck her — where a little context is worth a lot. That moment is perishable. Ten minutes later, the clarity is dimmer.

This is the central tension ShopFloor's capture model resolves:

- **Stash** (https://apps.apple.com/us/app/stash-anything-save-find/id6758998468) proves the zero-friction model works: Share Sheet, destination selector, done. 0.3 seconds. Nothing required. Their category suggestion is right 70%+ of the time.
- **Readwise** proves the resonance model works: when you highlight something, the system immediately surfaces a note field and tag options. Not required. Just there. And what Karen writes in that moment — "this is Echo's false belief, exactly, but from her mother's mouth" — is worth ten times what she'd write in a classification session later.

ShopFloor uses both. The capture sheet has two layers. Neither blocks the other.

**The Capture Sheet — Two Layers**

**Layer 1 (always visible — the Stash layer):**
- Content preview — what was captured, rendered cleanly
- Project selector — defaults to active project, one tap to change, AI suggests based on content
- **Save button** — always reachable, always immediate

Layer 1 is never more than three taps from seeing something to having it saved. Zero typing required. This is the floor for every capture, from any source.

**Layer 2 (surfaced below Layer 1 — the Readwise layer):**
- Note field — placeholder: *"What struck you?"* — empty, Karen types nothing she doesn't want to
- Quick entity chips — 3 to 4 of the most recently active characters, scenes, or wounds from session state. One tap to pre-assign.
- Source type selector — pre-populated by AI inference, editable

Layer 2 appears naturally in the same sheet, below the Save button. Karen sees it. She decides. If she's in a hurry, she ignores it and hits Save. If she's in a capturing mood — which she often is, because she just found something — she adds a note or taps an entity and hits Save. The particle arrives enriched.

**The Particle Inbox**

Particles with no project assignment (captured when no active project is set) go to a system-level Inbox. This mirrors Stash's explicit Inbox concept: no time to decide which project? Capture it anyway. Sort it in the next review session by swiping: swipe to assign, swipe to discard.

Karen never loses a particle to indecision about where it belongs.

**Status at Save — How Layer 2 Engagement Affects Status**

The status of a newly created particle is determined at save time by how much Karen engaged:

| Layer 2 engagement | Status at save |
|---|---|
| Nothing — saved from Layer 1 only | `raw` |
| Note added at capture | `considered` — Karen engaged; she knows why this matters |
| Entity pre-assigned at capture | `considered` — Karen made an explicit story connection |
| Both note and entity | `considered` |

The key insight: `considered` doesn't mean "classified by the system." It means "Karen has already started thinking about this one." Pre-assignment and capture notes are strong signals the system should honor.

**The iOS Share Sheet is the primary capture mechanism.**

ShopFloor registers as a Share Sheet extension. This means every app on iOS — Safari, Photos, Reddit, Instagram, Diarium, Obsidian, Bear, Day One, clipboard-based Shortcuts, anything — can send particles directly to ShopFloor with zero app-switching friction. The Share Sheet delivers the content, source app identity, and metadata automatically. Karen never types the source.

Every path to capture — Share Sheet, direct in-app typing, voice, Shortcut, paste, file drop — routes through the same capture sheet and the same two-layer model. The mechanism changes; the experience doesn't.

**Capture origin tracking:** Every particle records two things about how it entered the system — the *method* (a closed enum) and the *source* (an open string).

`captureMethod` — closed enum, controls processing logic:
- `share_sheet` — captured via iOS Share Sheet from any external app. Source app name auto-populated from Share Sheet metadata. **This is the primary mobile capture path.**
- `direct` — typed or spoken directly in-app by Karen
- `import` — pulled from an external data source via structured extract (batch operation)
- `sync` — ingested from a connected vault or note system (file-based, ongoing)
- `manual` — pasted, dragged in, or file-dropped via Files picker
- `promoted` — file already existed in Karen's notebooks; she elevated it to particle status

`sourceApp` — open string, provenance only. For `share_sheet` captures, this is auto-populated from the Share Sheet's source bundle metadata — Karen never types it. Any app, any future app, requires no schema change — just record the string. Never hardcode app names.

**Status lifecycle:** `raw → considered → developing → placed`. `shelved` is a lateral exit from any state except `placed`.

| Status | Meaning |
|--------|---------|
| `raw` | Promoted but not yet engaged with |
| `considered` | Karen engaged — resonance note added, or entity pre-assigned |
| `developing` | Karen is actively working this toward a Starting Line-Up |
| `placed` | Incorporated into an active project |
| `shelved` | Intentionally set aside — can be retrieved |

Status advances are logged to the audit trail. Initial status is set at promotion time based on Layer 2 engagement (see table above).

### 6.3 Verb Data Structures (Events and Processes)

These are the things that happen in Karen's story — tracked across scenes and chapters.

| Data Structure | Template Version | File Pattern |
|---|---|---|
| Scene_Inventory | 1.2 | `Scene_Inventory.json` (singleton) |
| Plot_Thread_Tracker | 1.1 | `Plot_Thread_THR001.json` |
| Arc_Beat_Sheet | current | `Arc_Beat_Sheet_CHR001.json` |
| Subplot_Profile | current | `Subplot_Profile_SUB001.json` |
| Revelation_Log | current | `Revelation_Log.json` (singleton) |
| Chapter_Profile | current | `Chapter_Profile_CHP001.json` |
| Turning_Point_Tag | current | `Turning_Point_TPT001.json` |
| Continuity_Log | current | `Continuity_Log.json` (singleton) |
| Pacing_Map | current | `Pacing_Map.json` (singleton) |
| Relationship_Arc | current | `Relationship_Arc_REL001.json` |

### 6.4 Scaffolding (Structural Intelligence)

These are the structures that enforce story rules. They are the primary target for completeness-checking skills.

| Data Structure | Template Version | Priority |
|---|---|---|
| Story_Spine | 1.1 | TIER 1 — Core engine |
| Conformance_Report | 1.1 | TIER 1 — Run after each draft pass |
| Thread_Registry | 1.0 | TIER 2 — Create at project outset |
| Beat_Registry | current | TIER 2 |
| Structural_Gap_Log | current | TIER 2 |
| Framework_Selector | current | TIER 2 |
| Act_Profile | current | TIER 2 |
| Conformance_History | current | TIER 3 |
| Custom_Framework_Builder | current | TIER 3 |

**Note:** Scene_Inventory appears in Section 6.3 (Verb Data Structures) as a singleton. It serves a dual role — both a tracking tool (verb) and a structural validation input (scaffolding). Its canonical home is Section 6.3. Scaffolding skills that need it declare it in their Context Requirements.

### 6.5 Frameworks

Stored as read-only JSON templates in `.shopfloor/frameworks/` at the system root (a sibling of the `skills/` directory, not inside it — frameworks are reference data, not executable skills). Karen selects a framework through conversation. The Framework_Selector scaffolding record captures the choice.

Available at v1.0 (StoryEngine vertical):
- Three-Act Structure
- Save the Cat (Blake Snyder)
- Seven-Point Story Structure
- Story Grid (Shawn Coyne)
- Hero's Journey (Campbell)

### 6.6 Operations Data Structures

These are the structures that manage the shop floor itself — not Karen's story, but the system's organizational health and performance. They live in `.shopfloor/object-model/` alongside story entities.

| Data Structure | Template Version | File Pattern |
|---|---|---|
| Role_Record | 1.0 | `Role_Record_DEV_EDITOR.json` |
| Scorecard | 1.0 | `Scorecard_DEV_EDITOR.json` |
| Team_Manifest | 1.0 | `Team_Manifest.json` (singleton) |

**Role_Record** — Per-project record of what a role has done. Chapters touched, open flags, skills invoked, last active timestamp. This is the role's resume for this specific project. One per role per project.

**Scorecard** — Per-role per-project performance summary derived from the audit trail. Invocations, acceptance rate, modification rate, ignored rate. Updated incrementally after each skill outcome event. This is how the floor knows which stations are performing.

**Team_Manifest** — Singleton record that captures which team is installed, which roles are active, and the routing rules that map Karen's requests to the appropriate role and station. The team manifest is the floor plan.

### 6.7 Content Files and Object Model — The Relationship

Karen may have a content file (`Characters/Echo Bullard.md`) and an object model entity (`Character_Profile_CHR001.json`) that both describe the same character. These are related but not the same thing.

- **The content file** is Karen's prose — her words, in her voice, in whatever form she chooses. It is above the waterline. She owns it.
- **The object model entity** is the system's structured understanding — fields, IDs, cross-references, version numbers. It is below the waterline. The system owns it.

**They are not synchronized.** If Karen edits `Echo Bullard.md` in a text editor and changes the character's name, the object model does not automatically update. The structured understanding only changes through skill-driven conversations (see Section 7, Write-Back Architecture).

**This is by design.** The content file is a living creative document. The object model is a structured snapshot built through intentional conversation. Automatic synchronization would require the system to interpret Karen's unstructured prose changes — a fragile and presumptuous operation. Instead, when Karen makes significant changes, she can invoke a skill: *"I've rewritten Echo's backstory — can you update your understanding?"* The appropriate role (the Developmental Editor station in StoryEngine) reads the content file, discusses the changes with Karen, and updates the object model through the normal write-back contract.

**The bridge:** The per-file metadata record (Section 5.3) connects them. The `linkedEntities` array on Echo Bullard's file record points to `CHR-001`. The app can display this connection. But the content file and the object model entity are free to diverge.

---

## 7. Write-Back Architecture

### 7.1 The Problem

The storage spec through Section 6 describes how data is organized and read. But skills also *create* and *update* data. When the character-creation skill finishes a conversation and has a full character profile, a chain of writes must happen atomically and correctly. This section specifies that chain.

### 7.2 The Write-Back Contract

Every skill that creates or modifies an entity follows this sequence. No exceptions.

**For entity creation (e.g., new Character_Profile):**

1. **Acquire next ID.** Read the `idCounters` dict in `manifest.json` for the entity type (e.g., `CHR`). Increment. Write the counter back immediately. This is a lightweight lock — no two entities can receive the same ID.

2. **Instantiate the template.** Copy the current JSON template for the entity type. Populate fields from the conversation. Set `schemaVersion` to the current template version. Set `profileVersion` to `1`. Set `dateCreated` and `dateModified` to now.

3. **Write the object model record.** Save to `.shopfloor/object-model/` using the naming convention: `[DataStructure]_[ID].json` (e.g., `Character_Profile_CHR003.json`).

4. **Update cross-references.** For every entity referenced by the new record (e.g., a Wound_Profile linked to this character), update that entity's `linkedEntities` array to include the new ID. Write each updated record.

5. **Register in manifest.** Add the new entity to the `objectModelRegistry` section of `manifest.json` with its ID, type, schema version, and creation date.

6. **Log to audit.** Append a `CREATE` entry to the audit trail with the entity ID, type, skill name, and role that owns the skill.

**For entity update (e.g., editing an existing Character_Profile):**

1. **Read current record.** Load the existing JSON file.
2. **Apply changes.** Update only the fields that changed.
3. **Increment `profileVersion`.** This is a simple integer increment.
4. **Update `dateModified`.** Set to now.
5. **Update cross-references** if any linked entities changed (e.g., new wound assigned).
6. **Write the record.** Overwrite in place.
7. **Log to audit.** Append an `UPDATE` entry with field-level change details.

### 7.3 Outcome Recording

After a skill completes and Karen sees the result, the app records events to the audit trail. Three event types are involved in tracking skill performance:

---

**`SKILL_OUTCOME`** — recorded every time a skill produces output and Karen responds.

```json
{
  "event": "SKILL_OUTCOME",
  "timestamp": "2026-04-13T09:14:00Z",
  "skillId": "character-creation",
  "skillVersion": "1.0",
  "role": "dev-editor",
  "sessionId": "SES-0042",
  "outcome": "accepted | modified | ignored",
  "entityId": "CHR-003"
}
```

> **`outcome`** — what Karen did with the skill's output:
> - `accepted` — used as-is; skill did its job
> - `modified` — used but Karen changed something before accepting; skill was partially right
> - `ignored` — not used; skill output was declined or session ended without action
>
> **`entityId`** — the record that was created or updated, if any. Empty for advisory skills that don't write an entity.

---

**`SKILL_FEEDBACK`** — recorded when Karen taps the optional evaluation prompt (👍 / 👎 / "tell me more"). Only appears when a skill is in `warranty` or `active` evaluation mode. Never recorded in `passive` mode.

```json
{
  "event": "SKILL_FEEDBACK",
  "timestamp": "2026-04-13T09:14:22Z",
  "skillId": "character-creation",
  "skillVersion": "1.0",
  "role": "dev-editor",
  "sessionId": "SES-0042",
  "rating": "positive | negative",
  "karensNote": "it skipped her relationship to her mother entirely",
  "evaluationMode": "warranty"
}
```

> **`rating`** — Karen's tap: `positive` (👍) or `negative` (👎).
>
> **`karensNote`** — Karen's optional free-text response when she taps "tell me more." This is the most valuable field in the entire feedback system — it is Karen's unfiltered reaction at the moment the skill output is in front of her. The `scorecard-updater` passes this note to the Scorecard's notes section. The Skill Designer reads it when improving the skill.
>
> **`evaluationMode`** — records which mode triggered this prompt (`warranty` or `active`). Used to segment feedback by phase when analyzing skill performance.

---

**`SKILL_WARRANTY_COMPLETE`** — recorded when a skill's invocation count reaches the warranty target. The floor evaluates graduation vs. flag at this moment.

```json
{
  "event": "SKILL_WARRANTY_COMPLETE",
  "timestamp": "2026-04-20T14:22:00Z",
  "skillId": "character-creation",
  "role": "dev-editor",
  "warrantyInvocations": 10,
  "acceptanceRate": 0.80,
  "modificationRate": 0.20,
  "ignoredRate": 0.00,
  "verdict": "graduated | flagged",
  "transitionedTo": "active | under_review"
}
```

> **`verdict`** — the floor's automated assessment at warranty end:
> - `graduated` — acceptance rate met or exceeded the quality threshold; skill moves to the role's default evaluation mode
> - `flagged` — acceptance rate fell below threshold; skill is marked `under_review` and Bill is notified; Karen is not interrupted
>
> **`transitionedTo`** — the skill's new evaluation mode following warranty:
> - `active` — normal post-warranty operation; Karen may be prompted occasionally
> - `under_review` — skill remains usable but is marked for attention; Bill should run the Skill Designer's "improve existing" flow

---

**How the app detects SKILL_OUTCOME:** For entity-creating skills, acceptance is implicit — the write-back ran, the entity exists. For advisory skills (suggestions, analysis), the app tracks whether Karen acted on the result within the session. If the session ends without action, the outcome defaults to `ignored`. If Karen explicitly confirms ("Yes, update that"), the outcome is `accepted`. If Karen confirms with changes ("Update it, but change the false belief to..."), the outcome is `modified`.

All three event types feed the Scorecard (Section 14). `SKILL_OUTCOME` drives the quantitative metrics. `SKILL_FEEDBACK` provides the qualitative signal. `SKILL_WARRANTY_COMPLETE` marks phase transitions.

### 7.4 ID Counters

`manifest.json` carries a counter dictionary that tracks the next available ID for each entity type:

```json
{
  "idCounters": {
    "CHR": 3,
    "SCN": 12,
    "WND": 2,
    "PRT": 47
  }
}
```

The counter is incremented *before* the entity is written. If the write fails, the counter is not rolled back — a gap in the sequence is harmless and preferable to a duplicate ID.

### 7.5 Cross-Reference Integrity

When a new entity references existing entities (e.g., a new Wound_Profile references Character `CHR-001`), the write-back must update both sides:

- The new Wound record stores `"characterID": "CHR-001"`
- The existing Character record's `linkedEntities` array gains `"WND-003"`

If the reverse update fails (e.g., the Character record is locked by iCloud sync), the system logs a `BROKEN_XREF` warning to the audit trail and flags it for repair at next session-init. The forward reference (Wound -> Character) is always written first and is sufficient for the system to self-heal later.

### 7.6 Failure Modes

| Failure | Consequence | Recovery |
|---|---|---|
| Write succeeds but manifest update fails | Entity exists but isn't registered | Session-init scans `object-model/` for unregistered records and registers them |
| Cross-reference update fails | One-sided link | Session-init `BROKEN_XREF` scan detects and repairs |
| ID counter write fails | Next session may assign same ID | ID collision detected at write time; system increments and retries |
| Complete write failure (disk full, iCloud conflict) | No entity created | Skill reports failure to Karen; conversation data preserved in chat history for retry |

No partial state is ever silently accepted. Every failure is logged and flagged for repair.

---

## 8. Schema Versioning

### 8.1 Every Record is Versioned

Every JSON record — per-file metadata, container manifest, and object model records — carries two version fields:

```json
{
  "schemaVersion": "1.0",
  "profileVersion": 2
}
```

`schemaVersion` identifies which version of the template was used to create this record (a string, e.g., `"2.1"`). `profileVersion` tracks how many times this specific record was updated (an integer, starting at 1). When templates evolve, ShopFloor can detect schema mismatches by comparing `schemaVersion` against the current template version.

### 8.2 Migration Strategy

When a skill reads a record with a `schemaVersion` older than the current template:

1. The skill reads the old record
2. It creates a new record using the current template
3. It maps old fields to new fields where names match
4. It flags new required fields as `"[MIGRATION-NEEDED]"`
5. It writes the new record and archives the old one to `.shopfloor/snapshots/`
6. It logs the migration to the audit trail

No data is ever deleted during migration. The archive is always available.

---

## 9. Conflict Resolution and iCloud Sync

### 9.1 Governing Principle: What Would Apple Do?

iCloud Drive handles file-level conflicts using last-write-wins with automatic versioning. When two devices write the same file simultaneously, iCloud creates a conflict copy (e.g., `manifest (Bill's MacBook's conflicted copy).json`).

ShopFloor's policy mirrors Apple's: **most recently modified file wins**. Conflict copies are moved to `.shopfloor/snapshots/` for review, never silently deleted.

### 9.2 Why This Works in Practice

Alfons Schmidt has been shipping Notebooks App for over a decade with this exact iCloud architecture, with hundreds of thousands of users across iPhone, iPad, and Mac, often using all three simultaneously. Conflicts severe enough to cause data loss are essentially unicorn events in practice. The architecture is battle-tested.

### 9.3 The Real Risk: Rename Lag

The more realistic problem is rename lag: Karen renames a chapter on iPhone. Before iCloud syncs, she opens her Mac and the chapter still shows the old name. This is a display inconsistency, not a data loss event. The UUID layer means the underlying object model stays correct — only the display name is temporarily stale.

### 9.4 Concurrency Within a Single Session

ShopFloor skills write to `.shopfloor/` serially within a session. No parallel writes from Claude within the same conversation. The risk is device-to-device, which iCloud handles.

---

## 10. Orphan Management

### 10.1 What Is an Orphan?

An orphan is any `.shopfloor/` record whose corresponding content file no longer exists on disk. This happens when:

- Karen deletes a chapter
- Karen moves a chapter out of the project folder
- A sync error leaves a ghost entry

### 10.2 Detection

The session-init skill (see Section 16) performs an orphan scan at the start of each desktop session:

1. Read `manifest.json` file registry
2. Check each registered UUID's `relativePath` against actual files on disk
3. Any UUID whose file does not exist at its expected path (or anywhere in the project tree) is promoted to `orphanRegistry`

### 10.3 Resolution

Orphans are never automatically deleted. They are:

1. Moved to `orphanRegistry` in `manifest.json`
2. Logged to the audit trail
3. Archived: the orphaned metadata record is moved to `.shopfloor/snapshots/orphans/`
4. A soft prompt is offered to Karen: *"I noticed 'Chapter Three' is no longer in your project. Should I forget everything I knew about it, or keep it in case you bring it back?"*

This is a floor management problem that a Tier 1 skill handles — not an error condition.

---

## 11. Self-Healing Behaviors

### 11.1 Triggers for Self-Healing

| Condition | Detection Method | Repair Action |
|---|---|---|
| File renamed | Correlation scan (see 11.1.1) | Update `currentFilename`, `relativePath` in metadata record and manifest |
| File moved | UUID record exists but `relativePath` doesn't match disk | Update `relativePath` in metadata record and manifest |
| File deleted | UUID in manifest, no file at `relativePath` or anywhere in project | Promote to orphan registry |
| Metadata missing | File exists on disk but no UUID record references it | Create new metadata record, assign UUID, register in manifest, log as new |
| Manifest missing | No `manifest.json` in `.shopfloor/` | Reconstruct from scanning all metadata records (cold start) |
| Schema mismatch | `schemaVersion` field doesn't match current template | Trigger migration (see Section 8.2) |
| Broken cross-reference | Object model record references an entity ID not found in `object-model/` | Flag in Conformance_Report, log `BROKEN_XREF` to audit |
| Scorecard drift | Scorecard totals don't match audit trail event counts | Recompute from audit trail (see Section 14.3) |

#### 11.1.1 Rename Detection — The Correlation Scan

A file rename is indistinguishable from a delete-plus-create at the filesystem level. The system detects renames by correlating orphaned records (records whose file is missing) against unregistered files (files with no metadata record) using three signals:

1. **macOS creation date.** macOS preserves the filesystem creation date (`kMDItemFSCreationDate`) through renames. If an orphaned record's `dateCreated` matches an unregistered file's creation date within 1 second, it's a rename.
2. **File size.** If creation dates are unavailable (e.g., after iCloud restore), file size matching serves as a weaker signal.
3. **Content hash (first 4KB).** If both signals above are ambiguous (multiple candidates), a partial content hash breaks the tie.

If a rename is detected, the system updates the metadata record's `currentFilename` and `relativePath` and logs a `RENAME` event to the audit trail. If no correlation is found, the orphan and new-file are treated as separate events (delete + create).

### 11.2 The Cold Start Recovery

The most extreme self-healing scenario: Karen gets a new device. iCloud restores her project folder. The `.shopfloor/` folder syncs from iCloud (it syncs like any other hidden folder — the dot-prefix only hides it from UI, not from iCloud).

If somehow `.shopfloor/` is missing or corrupt:

1. **Scan all `.md` files in the project folder**
2. **Check for orphaned metadata records** (records without matching content files) in case there was a partial sync
3. **Reconstruct `manifest.json`** from the recovered records
4. **Assign UUIDs to any files that lack them**
5. **Flag object model as `NEEDS-RECONSTRUCTION`** — a skill prompts Karen: *"I've recovered your files but I need to re-learn your story. Can you give me a few minutes to catch up?"*

This is a backup-restore skill. It is the escape hatch, not the normal path.

---

## 12. The Audit Trail

### 12.1 Location and Format

`.shopfloor/audit/audit.jsonl` — JSON Lines format, append-only, one event per line.

```json
{"ts":"2026-04-11T14:23:00Z","event":"CREATE","id":"8F3A2C1D","detail":{"filename":"Chapter One.md"},"actor":"karen","role":null}
{"ts":"2026-04-11T15:01:00Z","event":"RENAME","id":"8F3A2C1D","detail":{"old":"Chapter One.md","new":"The Beginning.md"},"actor":"karen","role":null}
{"ts":"2026-04-11T16:45:00Z","event":"UPDATE","id":"CHR-001","detail":{"field":"profileVersion","old":1,"new":2},"actor":"skill:character-creation","role":"dev-editor"}
{"ts":"2026-04-11T16:45:00Z","event":"ORPHAN","id":"9G4B3D2E","detail":{"filename":"Chapter Three.md"},"actor":"shopfloor","role":null}
{"ts":"2026-04-11T16:50:00Z","event":"MIGRATE","id":"CHR-001","detail":{"schemaVersion":{"old":"1.0","new":"1.1"}},"actor":"shopfloor","role":null}
{"ts":"2026-04-11T17:00:00Z","event":"CREATE","id":"WND-001","detail":{"type":"Wound_Profile","character":"CHR-001"},"actor":"skill:wound-intake","role":"dev-editor"}
{"ts":"2026-04-11T17:00:01Z","event":"XREF","id":"CHR-001","detail":{"added":"WND-001"},"actor":"skill:wound-intake","role":"dev-editor"}
{"ts":"2026-04-11T17:05:00Z","event":"STATUS","id":"PRT-00023","detail":{"old":"raw","new":"considered"},"actor":"skill:particle-review","role":"dev-editor"}
{"ts":"2026-04-11T17:10:00Z","event":"SKILL_OUTCOME","id":null,"detail":{"skill":"wound-intake","role":"dev-editor","outcome":"accepted"},"actor":"karen","role":"dev-editor"}
{"ts":"2026-04-11T17:15:00Z","event":"SKILL_OUTCOME","id":null,"detail":{"skill":"beat-sheet","role":"dev-editor","outcome":"modified","modifiedFields":["midpoint_crack"]},"actor":"karen","role":"dev-editor"}
```

**Why JSON Lines over pipe-delimited text:** Each line is a self-contained JSON object. No escaping ambiguity when filenames contain pipes, quotes, or newlines. Parseable by any JSON library. Still human-readable in a text editor. Still append-only.

**Fields:**
- `ts` — ISO 8601 timestamp
- `event` — event type: `CREATE`, `UPDATE`, `DELETE`, `RENAME`, `ORPHAN`, `MIGRATE`, `XREF`, `STATUS`, `SESSION_START`, `SESSION_END`, `BROKEN_XREF`, `EXPORT`, `SKILL_OUTCOME`, `ROLE_ACTIVATED`
- `id` — UUID (for content files) or entity ID (for object model records), null for non-entity events
- `detail` — event-specific data (structured object, not a flat string)
- `actor` — `karen` (user action), `shopfloor` (platform action), or `skill:[skill-name]` (specific skill)
- `role` — which role owned the action, null for platform-level or user-level events

### 12.2 Log Rotation

Logs are rotated monthly. `audit.jsonl` -> `audit-2026-03.jsonl`. Current log is always `audit.jsonl`. Skills that debug problems can reference historical logs.

---

## 13. The Shop Floor — Roles, Stations, and Teams

This section defines how work is organized. It answers: who does the work, where do they do it, and how does the floor know what's happening?

### 13.1 Roles

A **role** is a named area of expertise with defined responsibilities. It is the organizational building block of the shop floor. Each role has:

- **A name** — what you'd call this person if you hired them. Developmental Editor. Copy Editor. Continuity Guard.
- **Responsibilities** — a plain-English list of what this role does. Written by Bill (or by the Skill Designer in future versions).
- **Skills** — the system capabilities that fulfill each responsibility. Each skill belongs to exactly one role.
- **A station** — the loaded context (object model records, manifest, audit data) this role needs to do its work. The station is assembled dynamically by session-init based on the skills' context fingerprints.

Roles are defined in ROLE.md files stored in `.shopfloor/roles/` at the system root.

### 13.2 Role Definition Format (ROLE.md)

A ROLE.md is a plain-English job description that the system reads:

```markdown
# Developmental Editor

## Domain
Story structure, character psychology, narrative architecture, pacing.

## Responsibilities
- Evaluate story structure against the active framework
- Analyze character arcs for psychological coherence
- Identify weak motivation and missing wound activation
- Flag pacing problems and act-break failures
- Suggest scene reordering when structural analysis justifies it

## Skills
- character-creation (Tier 3)
- wound-intake (Tier 3)
- beat-sheet (Tier 3)
- character-arc-checker (Tier 2)
- conformance-reporter (Tier 2)

## Routing Triggers
Keywords and patterns that suggest this role should handle the request:
- character, motivation, arc, wound, backstory, psychology
- structure, pacing, act, beat, midpoint, climax
- "does this work", "is this believable", "what's missing"

## Voice
Direct. Structural. Asks hard questions about story logic.
Does not sugarcoat but explains the reasoning.
```

**Who writes ROLE.md files:** In v1, Bill writes them. They're part of the vertical definition. In v2+, the Skill Designer could generate them from a conversation where Karen (or Bill) describes what they need: *"I want someone who checks my dialogue for authenticity."*

### 13.3 Role Records (Per-Project)

Each role accumulates a project-specific record in `.shopfloor/object-model/`. This is the role's resume for this book:

```json
{
  "roleID": "dev-editor",
  "projectID": "1A2B3C4D-5E6F-7890-ABCD-EF0123456789",
  "schemaVersion": "1.0",
  "lastActive": "2026-04-11T17:30:00Z",
  "skillsInvoked": 14,
  "chaptersReviewed": ["CH-001", "CH-002", "CH-004"],
  "entitiesCreated": ["CHR-001", "CHR-002", "WND-001"],
  "openFlags": [
    "Act 2 midpoint missing — no scene pressures Echo's false belief",
    "Echo motivation unclear in CH-007"
  ],
  "lastSkillUsed": "wound-intake",
  "sessionCount": 7
}
```

The Role Record is updated at the end of each session where that role was active. Floor management (session-init, session-end) handles this automatically.

### 13.4 Stations

A **station** is not a file or a record — it's a runtime concept. When Karen starts working and the system routes her request to a role, the session-init skill assembles that role's station by:

1. Reading the ROLE.md to identify which skills the role owns
2. Reading the active skill's context fingerprint (Section 15.3)
3. Loading the declared object model records from `.shopfloor/object-model/`
4. Loading the manifest
5. Loading audit data if the skill requires it

The station is the working context: the right tools (skill instructions) and the right materials (object model data) for the job. Nothing more, nothing less.

A role may have multiple skills, but only one skill is active at a time. The station is configured for the active skill. If Karen switches tasks mid-session ("Actually, let's look at the beat sheet instead"), the station reconfigures — different skill, potentially different context fingerprint, different data loaded.

### 13.5 Teams

A **team** is the collection of roles that constitutes a vertical. Installing a vertical means installing a team. The team is defined in `team-manifest.json` at the system root:

```json
{
  "teamID": "storyengine-fiction",
  "teamName": "StoryEngine Fiction Team",
  "schemaVersion": "2.0",
  "vertical": "fiction",
  "roles": [
    {
      "roleID": "acquisitions-editor",
      "name": "Acquisitions Editor",
      "definitionPath": "roles/acquisitions-editor/ROLE.md",
      "tier1Skills": [],
      "tier2Skills": [],
      "tier3Skills": ["starting-lineup"]
    },
    {
      "roleID": "publisher",
      "name": "Publisher",
      "definitionPath": "roles/publisher/ROLE.md",
      "tier1Skills": [],
      "tier2Skills": [],
      "tier3Skills": ["greenlight-review"]
    },
    {
      "roleID": "developmental-editor",
      "name": "Developmental Editor",
      "definitionPath": "roles/developmental-editor/ROLE.md",
      "tier1Skills": [],
      "tier2Skills": ["character-arc-checker", "conformance-reporter"],
      "tier3Skills": ["character-creation", "wound-intake", "beat-sheet", "scene-development"]
    },
    {
      "roleID": "proofreader",
      "name": "Proofreader",
      "definitionPath": "roles/proofreader/ROLE.md",
      "tier1Skills": [],
      "tier2Skills": ["timeline-validator", "continuity-checker", "thread-drift-detector"],
      "tier3Skills": ["voice-profiler"]
    },
    {
      "roleID": "managing-editor",
      "name": "Managing Editor",
      "definitionPath": "roles/managing-editor/ROLE.md",
      "tier1Skills": ["session-init", "orphan-manager", "schema-migrator", "backup-restore", "project-export", "skill-installer", "routing", "scorecard-updater"],
      "tier2Skills": [],
      "tier3Skills": ["skill-designer"]
    }
  ],
  "routingRules": {
    "method": "keyword_match_then_clarify",
    "fallbackRole": "acquisitions-editor",
    "ambiguityThreshold": 0.6,
    "clarificationPrompt": "Are you working on a new idea, or developing something already in progress?"
  }
}
```

**Routing rules:** When Karen asks a question, the system matches her language against each role's routing triggers (defined in the ROLE.md). If one role matches clearly, that station activates. If multiple roles match above the ambiguity threshold, the system asks Karen to clarify. If nothing matches, the fallback role handles it.

### 13.6 Floor Management

**Floor management** is the work of keeping the shop floor running — not producing Karen's story, but maintaining the infrastructure that makes production possible. Floor management is the Managing Editor role (in StoryEngine's team), executing Tier 1 system skills. Karen never interacts with the Managing Editor directly — it runs behind the scenes.

| Floor Management Task | Skill | When It Runs |
|---|---|---|
| Session startup and context loading | session-init | Every desktop session start |
| Orphan detection and archival | orphan-manager | Every session-init |
| Schema version migration | schema-migrator | When mismatch detected |
| Backup and disaster recovery | backup-restore | On demand or after corruption |
| Object model export to markdown | project-export | On Karen's request |
| Mobile-to-desktop skill sync | skill-installer | When pending/ has files |
| Request routing to appropriate role | routing | Every Karen message |
| Performance tracking | scorecard-updater | After every skill outcome |

Floor management is invisible to Karen. She doesn't know these skills exist. She just knows the system works.

---

## 14. Quality Control — Scorecards and Outcome Tracking

### 14.1 The Principle

A well-run floor knows which stations are producing good work and which ones need attention. ShopFloor tracks this through **outcome events** (what happened) and **scorecards** (how well it went).

### 14.2 Outcome Events

Every skill invocation eventually produces an outcome: accepted, modified, or ignored (see Section 7.3). These outcomes are logged to the audit trail as `SKILL_OUTCOME` events with the skill name, the role, and the outcome type.

### 14.3 Scorecards

A **Scorecard** is a per-role, per-project performance summary. It is stored in `.shopfloor/object-model/` and updated incrementally by the scorecard-updater skill (Tier 1, floor management) after each `SKILL_OUTCOME` event.

```json
{
  "roleID": "dev-editor",
  "projectID": "1A2B3C4D-5E6F-7890-ABCD-EF0123456789",
  "schemaVersion": "1.0",
  "totalInvocations": 14,
  "outcomes": {
    "accepted": 9,
    "modified": 4,
    "ignored": 1
  },
  "acceptanceRate": 0.64,
  "modificationRate": 0.29,
  "ignoredRate": 0.07,
  "skillBreakdown": {
    "wound-intake": {"invocations": 3, "accepted": 3, "modified": 0, "ignored": 0},
    "beat-sheet": {"invocations": 5, "accepted": 2, "modified": 2, "ignored": 1},
    "character-creation": {"invocations": 4, "accepted": 3, "modified": 1, "ignored": 0},
    "conformance-reporter": {"invocations": 2, "accepted": 1, "modified": 1, "ignored": 0}
  },
  "lastUpdated": "2026-04-11T17:15:00Z",
  "lastAuditEventProcessed": "2026-04-11T17:15:00Z"
}
```

**What the scorecard tells you:**
- The Developmental Editor has a 64% straight-acceptance rate — good, but not great.
- The beat-sheet skill has a 40% modification rate and an ignored event. That skill might need refinement.
- The wound-intake skill has a 100% acceptance rate. It's doing its job well.

### 14.4 The Feedback Loop

```
Karen uses a skill
    → outcome recorded to audit trail
        → scorecard updated
            → Skill Designer reads scorecard
                → "This skill needs improvement"
                    → revised skill deployed
```

This is organizational learning, not machine learning. The system accumulates performance data and uses it to improve — the same thing a manager does when they review a team member's work and adjust the process.

**Who reads scorecards?** In v1, Bill reads them to understand which skills need work. In v2+, the Skill Designer could read them automatically and suggest refinements: *"The beat-sheet skill has been modified in 4 of the last 5 uses. The midpoint analysis is consistently changed. Want me to adjust how it evaluates midpoints?"*

### 14.5 Scorecard Integrity

The scorecard carries a `lastAuditEventProcessed` timestamp. Incremental updates read only events after that timestamp. If the scorecard drifts (totals don't match audit trail counts), the self-healing system (Section 11.1) triggers a full recompute from the audit trail. Full recompute is a Tier 1 skill, run on demand or when drift is detected.

---

## 15. Skill Architecture — Tiers and Context

### 15.1 Three Tiers

**Tier 1 — System Skills (Floor Management, never user-modifiable)**
Core infrastructure: session-init, orphan manager, schema migration, backup-restore, project export, routing, scorecard updater. These live in `.shopfloor/skills/system/`. Karen cannot see, invoke, or modify these directly. They run automatically. They belong to the Story Keeper role (or its equivalent in other verticals).

The **project-export** skill deserves special mention. It writes the entire object model to human-readable markdown — one `.md` file per entity, organized by type — to a folder Karen specifies. This is the No Roach Motel guarantee (Principle 2.2) applied to structured data. Karen can invoke it through conversation: *"Export everything you know about my story."*

**Tier 2 — Rule Skills (Quality Control, Karen-invokable)**
Completeness rules: character arc checker, timeline validator, continuity log, conformance reporter, thread drift detector. These are the **quality control inspections** of the shop floor. Karen can invoke them through conversation ("Does my story have any continuity problems?") but cannot edit them. Bill writes and updates these. They belong to the role whose domain they serve.

**Tier 3 — Creative Skills (Production, future Karen-extensible)**
Character creation, conflict management, scene development, voice profiling. These are the **production work** of the shop floor — the actual making. In Version 1, Bill writes them. In future versions, Karen may be able to create new ones through conversation with the Skill Designer — the Skill Designer outputs a new SKILL.md that gets written to this tier.

### 15.2 The Context Milk Problem

As Karen's story grows, the object model grows with it. Six characters, twenty scenes, three plot threads, a full wound library, a conformance history — all stored in `.shopfloor/object-model/`. If every skill loads all of it, two problems emerge:

1. **Performance degrades.** The AI's working memory has limits. A bloated context means shallower reasoning on the task at hand.
2. **Conflicts multiply.** Unrelated data creates noise. The wound profiles for three other characters are irrelevant — and potentially confusing — when Karen is building a new scene.

The fix is simple: **each skill declares exactly what it needs, and only that gets loaded.**

This is the Modular Persona pattern applied to the object model layer. Each SKILL.md is a specialized tool at a specific station. It knows its job. It brings only the materials that job requires.

### 15.3 Context Declaration — How It Works

Every SKILL.md file contains a `## Context Requirements` section in its header. This section is machine-readable and processed by the session-init skill before the conversation begins.

**Example — character-creation skill (Developmental Editor station):**

```markdown
## Context Requirements
objectModel:
  - Character_Profile: all          # All existing characters (for name/relationship checks)
  - Wound_Profile: linked           # Only wounds linked to the character being created
  - Conflict_Tag: linked            # Only conflicts linked to this character
  - Relationship_Profile: linked    # Existing relationships this character touches
manifest: true                      # Always needed — it's the table of contents
auditLog: false                     # Not needed for creative work
scaffolding: none                   # No structural scaffolding needed
```

**Example — conformance-reporter skill (Developmental Editor station):**

```markdown
## Context Requirements
objectModel:
  - Scene_Container: all            # Every scene — this skill reads the whole story
  - Beat_Registry: all              # All beats across the active framework
  - Story_Spine: singleton          # The single Story Spine for this project
  - Structural_Gap_Log: singleton   # Running gap history
manifest: true
auditLog: false
scaffolding: all                    # Full scaffolding layer needed
```

**Example — continuity-checker skill (Copy Editor / Continuity Guard station):**

```markdown
## Context Requirements
objectModel:
  - Scene_Container: all
  - Timeline_Entry: all
  - Continuity_Log: singleton
  - Character_Profile: all          # For tracking who is where, when
  - Location_Profile: all           # For tracking where scenes happen
manifest: true
auditLog: true                      # Continuity checker reviews history
scaffolding: none
```

### 15.4 Loading Rules

The session-init skill reads the active skill's Context Requirements and loads accordingly:

| Scope value | Meaning |
|---|---|
| `all` | Load every record of this type from `object-model/` |
| `linked` | Load only records whose entity ID appears in the active entity's `linkedEntities` array. **During entity creation, `linked` resolves to an empty set** — the entity doesn't exist yet, so there are no links to follow. This is expected behavior, not an error. |
| `singleton` | Load the single instance of this record type (e.g., `Story_Spine.json`) |
| `none` | Do not load this category |
| `false` | Do not load this item |

### 15.4.1 Active Entity Resolution

The `linked` scope depends on knowing which entity is "active" — the one whose links are followed. The active entity is determined by one of three methods, checked in this order:

1. **Explicit parameter.** The app or skill invocation passes an entity ID (e.g., Karen taps on Echo Bullard's character card, activeEntity = `CHR-001`).
2. **Session state.** If no explicit parameter, the session-init skill reads `session-state.json` for the last active entity.
3. **None.** If no active entity can be determined, all `linked` scopes resolve to empty sets. The skill operates in creation mode.

**The discipline this enforces:** when writing a skill, the author must explicitly ask *"what does this skill actually need to do its job?"* Everything else stays off the station. This is not an optimization — it is a design constraint that keeps skills focused, fast, and reliable as the object model scales.

### 15.5 Skill Registry

`.shopfloor/system-manifest.json` maintains a registry of all skills, including context fingerprints for quick loading decisions and role assignments:

```json
{
  "skillRegistry": [
    {
      "skillID": "character-creation",
      "tier": 3,
      "role": "dev-editor",
      "version": "1.0",
      "deploymentTargets": ["mobile", "desktop"],
      "path": "skills/creative/character-creation/SKILL.md",
      "status": "active",
      "contextFingerprint": {
        "objectModel": [
          "Character_Profile:all",
          "Wound_Profile:linked",
          "Conflict_Tag:linked",
          "Relationship_Profile:linked"
        ],
        "manifest": true,
        "auditLog": false,
        "scaffolding": "none"
      }
    }
  ],
  "quality_control": {
    "warranty_invocations": 10,
    "active_mode_frequency": 3,
    "default_evaluation_mode": "active",
    "modification_threshold": 0.40
  }
}
```

**`skillRegistry`** — the index of every installed skill. Allows session-init to make context-loading decisions without opening every SKILL.md file first. The `contextFingerprint` here mirrors the `## Context Requirements` section in the SKILL.md exactly — these two representations must stay in sync. The `role` field ties the skill to its owning role. The `deploymentTargets` field is the critical mobile/desktop routing tag.

**`quality_control`** — the factory settings for skill performance evaluation. These are the system-wide defaults. Individual roles and skills can override them in their Scorecard records, but this block defines what "out of the box" looks like:

> **`warranty_invocations`** — how many uses a newly installed skill gets during its warranty period before the floor evaluates it. Default: 10. During warranty, every use prompts Karen for lightweight feedback (👍 / 👎 / "tell me more"). This is the most concentrated signal the floor will ever collect about a new skill — the first 10 uses, while Karen's reactions are unfiltered.
>
> **`active_mode_frequency`** — after warranty, how often the floor prompts Karen for feedback in `active` evaluation mode. Default: 3 (every third use). Not every use — that would be intolerable. Occasional enough to keep signal flowing without interrupting Karen's work.
>
> **`default_evaluation_mode`** — the mode every skill transitions to after it graduates warranty. `active` means the floor keeps asking occasionally. `passive` means it stops asking and only observes behavior. Default: `active`. Bill can set individual skills to `passive` when the feedback friction outweighs the signal value.
>
> **`modification_threshold`** — the modification rate (as a decimal — 0.40 = 40%) above which the floor considers a skill a candidate for improvement. If Karen is changing the output of a skill more than 40% of the time, the system flags it. This does not mean the skill has failed — it means someone should look at it. A creative writing skill with 50% modification may be working exactly as intended; Karen enriches the output by design. A quality-control skill (timeline validator, continuity checker) with 40% modification means it is wrong nearly half the time, which is a real problem. The threshold is a signal, not a verdict.

---

## 16. Session Initialization and Skill Execution

### 16.1 Desktop Session Init

At the start of every desktop session, floor management runs automatically:

1. **Locate project** — identify active project folder
2. **Read manifest** — load `manifest.json`
3. **Orphan scan** — check all registered UUIDs against disk (Section 10)
4. **Schema check** — compare all record `schemaVersion` fields against current templates
5. **Skill sync** — compare iCloud skill library against local cache; sync any deltas
6. **Scorecard integrity check** — verify scorecards match audit trail (Section 14.5)
7. **Audit append** — log `SESSION_START` to the audit trail
8. **Route request** — determine which role and skill this session will use (from conversation context, explicit invocation, or routing rules — Section 13.5)
9. **Activate role** — log `ROLE_ACTIVATED` to audit trail, update role record
10. **Assemble station** — read the skill's `contextFingerprint` from the skill registry (Section 15.5), load only the declared object model records using the scope rules in Section 15.4
11. **Ready** — conversation begins with a lean, focused context at the right station

### 16.2 Skill Execution Model

The app is the shell. Claude is the intelligence. The SKILL.md is the instruction set. Here is how they work together:

1. **Karen acts.** She taps a skill pill, asks a question, or the app identifies the appropriate skill from context using the routing rules.
2. **The app reads the SKILL.md.** This is a markdown file containing the skill's instructions, conversation flow, output format, and write-back rules. The ROLE.md provides the voice and domain context.
3. **The app loads context.** Using the skill's `contextFingerprint`, it reads the declared object model records from `.shopfloor/object-model/` and the manifest.
4. **The app bundles and sends.** The SKILL.md instructions + ROLE.md voice + loaded context + Karen's message are sent to the Claude API. The SKILL.md becomes the system prompt. The ROLE.md shapes the voice. The context becomes reference data. Karen's message is the user turn.
5. **Claude responds.** The AI follows the skill's instructions, has the conversation with Karen, and produces two outputs: the words Karen sees (conversational response) and structured data to be persisted (in a defined output format the app can parse).
6. **The app writes back.** It parses the structured output and executes the write-back contract (Section 7): creates or updates records, updates cross-references, registers in manifest, logs to audit.
7. **The app records outcome.** Karen's response to the output is tracked (Section 7.3) and logged as a `SKILL_OUTCOME` event.
8. **The app confirms.** Karen sees the result — a card, a confirmation, a score. The `session-state.json` is updated with the current context. The scorecard is incrementally updated.

**The SKILL.md is not a script the app interprets — it is instructions the AI follows.** This distinction matters for skill authors. The skill's power comes from Claude's reasoning, not from programmatic logic. The app's job is limited to: read, bundle, send, parse, write, track.

### 16.3 Session State

`.shopfloor/session-state.json` tracks where Karen left off:

```json
{
  "lastSessionTimestamp": "2026-04-11T17:30:00Z",
  "lastActiveSkill": "wound-intake",
  "lastActiveRole": "dev-editor",
  "lastActiveEntity": "CHR-001",
  "pendingActions": [
    {
      "type": "incomplete_entity",
      "entityID": "WND-001",
      "fieldsPopulated": 3,
      "fieldsTotal": 7,
      "description": "Echo's wound profile — origin and false beliefs complete, triggers and behaviors remaining"
    }
  ],
  "resumptionPrompt": "Last time you were building Echo's wound profile with the Developmental Editor. You got through the origin and the false beliefs. Ready to pick up where you left off?"
}
```

At session start, if `session-state.json` exists and has pending actions, the app can offer Karen the resumption prompt before beginning new work. This directly supports the progress principle: Karen sees that work was done, work remains, and the system remembers where she was.

### 16.4 Mobile Session

Mobile has no session-init skill because there is no filesystem access. The mobile experience is:

1. Karen opens the app on iPhone
2. The conversation-bound skill content she needs is either in Master Instructions (always available) or she pastes it from a Shortcut
3. Any object model updates that result from the conversation are expressed as text Karen can paste into a note or send to herself
4. At next desktop session, the session-init skill processes any pending updates

This is the mobile impedance mismatch. The architecture minimizes it but cannot eliminate it without a native app.

---

## 17. iCloud Drive Root Layout

```
iCloud Drive/
  StoryEngine/                              <- Product root (vertical-specific)
    Inbox/                                  <- System-level inbox (no project assigned)
    .shopfloor/                             <- Hidden platform layer
      system-manifest.json                  <- Global registry: skills, roles, version
      team-manifest.json                    <- Team definition for this vertical
      roles/                                <- Role definitions (five roles, locked 2026-04-14)
        acquisitions-editor/ROLE.md         <- Particle → Starting Line-Up
        publisher/ROLE.md                   <- Go / no-go decision
        developmental-editor/ROLE.md        <- Post-greenlight: structure, character, arc
        proofreader/ROLE.md                 <- Correctness, consistency, style — last mile
        managing-editor/ROLE.md             <- Floor infrastructure (invisible to Karen)
      frameworks/                           <- Read-only framework templates
        three-act.json
        save-the-cat.json
        seven-point.json
        story-grid.json
        heros-journey.json
      skills/
        system/                             <- Tier 1 — floor management (Managing Editor)
          session-init/SKILL.md
          orphan-manager/SKILL.md
          schema-migrator/SKILL.md
          backup-restore/SKILL.md
          project-export/SKILL.md
          skill-installer/SKILL.md
          routing/SKILL.md
          scorecard-updater/SKILL.md
        rules/                              <- Tier 2 — quality control
          character-arc-checker/SKILL.md
          timeline-validator/SKILL.md
          continuity-checker/SKILL.md
          conformance-reporter/SKILL.md
          thread-drift-detector/SKILL.md
        creative/                           <- Tier 3 — production
          starting-lineup/SKILL.md          <- First proof-of-concept (Acquisitions Editor)
          greenlight-review/SKILL.md        <- Publisher decision skill
          character-creation/SKILL.md
          wound-intake/SKILL.md
          beat-sheet/SKILL.md
          scene-development/SKILL.md
          voice-profiler/SKILL.md
          skill-designer/SKILL.md           <- The meta-skill (Managing Editor)
        pending/                            <- Skills awaiting installation
          [any SKILL.md files drafted on mobile]
    My Novel/                               <- Karen's project
      Inbox/                                <- Project-level inbox (unassigned captures)
      [content files — .md, Karen-visible]
      .shopfloor/
        manifest.json
        session-state.json
        files/                              <- Per-file UUID metadata (particle tags live here)
        object-model/                       <- Entity records + Role records + Scorecards
        audit/
          audit.jsonl
        snapshots/
    KILLSWITCH/                             <- Karen's second project
      Inbox/
      [content files]
      .shopfloor/
        [same structure as above]
```

---

## 18. Data Structures Inventory

The following data structures are implemented as JSON templates in the object model layer. All are versioned. All carry `schemaVersion` and `profileVersion` fields matching their original designs.

### Noun Data Structures (19 total)
Character_Profile v2.1, Location_Profile v2.1, Scene_Container, Relationship_Profile, Group_Profile, Event_Profile, Timeline_Entry, Object_Profile, Region_Profile, POV_Profile, Narrator_Profile, Voice_Profile, Theme_Statement, Wound_Profile, Wound_Tag, Conflict_Tag, Motif_Profile, Era_Profile, Particle v1.0

### Verb Data Structures (10 total)
Scene_Inventory v1.2, Plot_Thread_Tracker v1.1, Arc_Beat_Sheet, Subplot_Profile, Revelation_Log, Chapter_Profile, Turning_Point_Tag, Continuity_Log, Pacing_Map, Relationship_Arc

### Scaffolding (9 total)
Story_Spine v1.1, Conformance_Report v1.1, Thread_Registry v1.0, Beat_Registry, Structural_Gap_Log, Framework_Selector, Act_Profile, Conformance_History, Custom_Framework_Builder

### Operations (3 total — NEW in v1.0)
Role_Record v1.0, Scorecard v1.0, Team_Manifest v1.0

### Frameworks (5 at v1.0)
Three-Act, Save the Cat, Seven-Point, Story Grid, Hero's Journey

---

## 19. Bottleneck Analysis — Where the Floor Gets Crowded

These are the places where performance, consistency, or usability will degrade first as the system scales. Each bottleneck includes its mitigation strategy. Implementation should address these in priority order.

### 19.1 Context Window Saturation (Critical)

**The problem:** As the object model grows, even selective loading via context fingerprints can fill Claude's context window. A skill that loads `Character_Profile: all` with 20 characters is loading 20 full JSON records — potentially 40-60KB of context before the conversation even starts.

**Mitigation:**
- **Summary records.** For `all` scope loads, provide a lightweight summary mode: entity ID, name, and key fields only. Full records loaded on demand during the conversation.
- **Pagination.** Skills can declare a load limit: `Character_Profile: all(max:10)`. The session-init skill loads the 10 most recently modified, with a mechanism to request more.
- **Skill Designer responsibility.** The Skill Designer must warn when a context fingerprint is likely to exceed thresholds. This is a design-time check, not a runtime check.

### 19.2 Write-Back Fan-Out (High)

**The problem:** Creating a scene that references 6 characters, 2 locations, and 3 conflicts means updating 11 other entity records' cross-reference arrays. Each update is a file read + modify + write. If iCloud is active, 12 files need to sync.

**Mitigation:**
- **Deferred cross-reference updates.** Queue reverse-link updates and execute them in batch at session-end rather than inline during entity creation. The forward link (scene → character) is always written immediately and is sufficient for queries.
- **Eventual consistency.** Accept that reverse links (character → scene) are a convenience cache, not authoritative. The conformance reporter reconstructs them from forward links when needed.

### 19.3 Session-Init Overhead (High)

**The problem:** 11 steps before Karen can start working. For a large project, the orphan scan alone requires reading the manifest and checking every UUID against disk.

**Mitigation:**
- **Project fingerprint.** Hash the manifest's `dateModified` and file count. If unchanged since last session, skip the orphan scan and schema check. These are the expensive steps.
- **Progressive loading.** Start the conversation immediately with the skill instructions and minimal context. Load remaining object model records in parallel while Karen types her first message.
- **Lazy scorecard check.** Defer scorecard integrity verification to background, don't block session start.

### 19.4 Audit Trail Growth (Medium)

**The problem:** Append-only JSONL files grow without bound within a rotation period. A productive session might generate 50+ events. Monthly rotation helps, but December's log for an active writer could be large.

**Mitigation:**
- **Scorecards are incrementally updated,** not derived from full audit scans. The `lastAuditEventProcessed` pointer ensures only new events are read.
- **Audit tail.** Common operations ("show last N events") read from the end of the file, not the beginning. JSONL is line-oriented and supports efficient tail reads.
- **Archival.** Logs older than 6 months are compressed and moved to `.shopfloor/snapshots/audit-archive/`. Still accessible but not in the hot path.

### 19.5 Mobile Impedance (Critical, Architectural)

**The problem:** The biggest user-facing bottleneck. Work done on mobile doesn't persist to the object model until Karen is back on desktop. Structured updates wait. Scorecards don't update. The shop floor is effectively closed when Karen is on her phone.

**Mitigation:**
- **The native app (Open Question #1) is the real fix.** A native app has filesystem access on both platforms.
- **Until then:** pending actions queue (already in session-state), with clear Karen-facing messaging about what was captured vs what was persisted. Karen should never lose work — only persistence is delayed.

### 19.6 Role Routing Ambiguity (Medium)

**The problem:** When Karen asks "Does Echo's backstory make sense?", which role handles it? Developmental Editor (structural) or Continuity Guard (consistency)? If responsibilities overlap, the system routes wrong.

**Mitigation:**
- **Non-overlapping responsibilities.** Each role's ROLE.md must have clearly distinct responsibilities. The Skill Designer should flag overlaps at design time.
- **Routing with clarification.** If the routing skill matches multiple roles above the ambiguity threshold, it asks Karen rather than guessing: *"Should I look at this from a structure perspective or a continuity perspective?"*
- **Fallback role.** When nothing matches, the team's designated fallback handles it (Developmental Editor in StoryEngine).

### 19.7 Skill Designer Context Hunger (High)

**The problem:** The Skill Designer is the most context-hungry operation on the floor. It needs to understand all data structures, all existing roles, all existing skills, the write-back contract, the context fingerprint system, and the tier model. This is the meta-bottleneck: the tool that builds all other tools needs the most context.

**Mitigation:**
- **Compressed reference.** The Skill Designer loads a schema index (type names, field lists, ID formats) rather than full schemas. It requests full schemas only for the specific types the new skill will touch.
- **Role index.** A summary of all roles and their responsibilities, not the full ROLE.md files.
- **The Skill Designer's own SKILL.md must be the most context-efficient skill on the floor.** This is a hard design constraint.

### 19.8 Cross-Reference Integrity at Scale (Medium)

**The problem:** The N+1 problem applied to file-based storage. A protagonist who appears in every scene has cross-references in dozens of Scene_Container records. Updating, verifying, or repairing these references scales linearly with connection count.

**Mitigation:**
- **Forward links are authoritative.** The entity that creates the relationship stores the link. Reverse links are caches that can be rebuilt.
- **Batch repair.** The conformance reporter detects broken cross-references and repairs them in batch, not one at a time. One scan, all fixes.

### 19.9 iCloud Sync Throughput (Medium)

**The problem:** After a heavy session (creating multiple entities, running conformance), many files in `.shopfloor/` change. iCloud syncs files individually. A burst of 20+ file changes can take minutes to fully propagate.

**Mitigation:**
- **Batch manifest updates.** Instead of writing `manifest.json` after every entity creation (the most-written file), queue manifest updates and write once at session-end.
- **Accept eventual consistency.** iCloud sync lag is a reality. The system is designed to detect and heal inconsistencies at session-init. Lag is tolerated; corruption is not.

### 19.10 Scorecard Staleness (Low)

**The problem:** If scorecard incremental updates fail or the process is interrupted, the scorecard drifts from the audit trail source of truth.

**Mitigation:**
- **Self-healing detects drift** (Section 11.1). If totals don't match, the scorecard is recomputed from audit events.
- **The scorecard is a cache, not a source of truth.** It can always be rebuilt from the audit trail. Staleness is an inconvenience, not a data loss.

---

## 20. Open Questions (The Remaining 30%)

These are the decisions not yet resolved in this specification. Closed questions are marked with their resolution date.

| # | Question | Status | Resolution / Options | Priority |
|---|---|---|---|---|
| 1 | **Native app vs file system as app** | **CLOSED 2026-04-14** | Native iOS/macOS app. Filesystem with UI frontend. File I/O is always client-side. iCloud handles sync. Reference architecture: Notebooks App (Alfons Schmidt). | — |
| 2 | **Skill/Content Boundary — enforcement** | Open | How does the system prevent Karen from accidentally writing into `.shopfloor/`? iOS/macOS hide it but a technical Karen could still find it. | High |
| 3 | **Mobile skill runtime** | **CLOSED 2026-04-14** | Native app has full filesystem access on iOS. The Shortcut bridge workaround is obsolete. | — |
| 4 | **Object model update trigger** | **CLOSED 2026-04-14** | Explicit skill invocation only. The object model is never updated automatically — only when Karen invokes a skill that produces structured output. | — |
| 5 | **Karen's Skill Extension path** | **CLOSED 2026-04-14** | Karen describes a felt need in plain English. The Skill Designer (Managing Editor meta-skill) handles it in Karen mode: translates felt need → skill concept, gets Karen's approval, writes SKILL.md to `skills/pending/` for Bill's review. Karen never touches YAML or technical format. | — |
| 6 | **Conformance Report frequency** | Open | How often does the system run completeness checks? Always-on background? On demand? After each chapter? | Medium |
| 7 | **Multi-project context** | Open | Can Karen ask a question that spans two projects ("Does Echo's voice sound like my character in KILLSWITCH?")? | Medium |
| 8 | **Skill Designer scope** | **CLOSED 2026-04-14** | Both Bill and Karen, with different flows. Bill mode: accepts technical spec directly, validates, writes to active tier. Karen mode: felt need → concept → approval → `pending/` for review. Both use the same nine-section SKILL.md format. Same templates, different entry points and routing paths. | — |
| 9 | **Role creation by Karen** | Open | In v2+, can Karen create entirely new roles through conversation? What guardrails prevent role proliferation? | Medium |
| 10 | **Shared skills across roles** | **CLOSED 2026-04-14** | Continuity Guard eliminated. Continuity Guard's skills absorbed into Proofreader. Clean role boundaries — no shared skill ownership. | — |
| 11 | **Audit log access** | Open | Should Karen ever see audit log output, or is it purely for debugging? | Low |
| 12 | **Snapshot retention policy** | Open | How long are snapshots kept? How many versions? Who prunes them? | Low |

---

## 21. Status as of 2026-04-14

**Design phase complete. No code yet.**

### Done
- [x] Five ROLE.md files — `Roles/[role]/ROLE.md` for all five roles (locked 2026-04-14)
- [x] `Data Structures/Noun Data Structures/Starting_Lineup.md` — v1.1 with JSON schema
- [x] `Data Structures/Operations/Project.md` — project record schema (AE + Publisher phases)
- [x] `.shopfloor/schema-index.json` — compact schema index for Skill Designer (46 schemas)
- [x] `.shopfloor/role-index.json` — compact role index for Skill Designer (5 roles)
- [x] `.shopfloor/skill-registry.json` — skill registry seed (starting-lineup, skill-designer)
- [x] `Skills/creative/starting-lineup/SKILL.md` — first proof-of-concept skill (AE intake, Tier 3)
- [x] `Skills/creative/skill-designer/SKILL.md` — meta-skill (Managing Editor, Tier 3)

### Architecture decisions locked as of 2026-04-14
- Native iOS/macOS app (Question #1 closed)
- Object model updates on explicit skill invocation only (Question #4 closed)
- Mobile skill runtime = native app (Question #3 closed)
- Five roles: acquisitions-editor, publisher, developmental-editor, proofreader, managing-editor (Question #10 closed)
- Particle = tag on a file (isParticle in per-file metadata, not a standalone entity)
- Karen's Skill Extension path = Skill Designer Karen mode → pending/ (Question #5 closed)
- Skill Designer serves both Bill and Karen with separate flows (Question #8 closed)

### Pending spec cleanup
- [ ] Add `writable_by` field to all 46 data structure schema templates
- [ ] Write `Data Structures/Operations/System_Manifest.md` schema template
- [ ] Update this spec's audit trail section (Section 7) with new event types from Skill Designer Spec Section 13
- [ ] Add `writable_by` permission enforcement model to Section 7 write-back architecture

### Next skills to write (in order)
1. `Skills/creative/greenlight-review/SKILL.md` — Publisher go/no-go decision (Tier 3)
2. Tier 1 floor management skills (Managing Editor) — required before any end-to-end session
3. Tier 2 quality control skills

**Reference architecture:** Notebooks App by Alfons Schmidt. Study its metadata conventions. Adopt the structure, not the placement or the format.

---

*v0.6-0.7: Synthesized from design conversation on 2026-04-11. v0.8: Design flaw audit — added write-back architecture, Particle entity, dual identity system, rename detection, active entity resolution, UUID-based metadata naming. v0.9: Format migration from plist (XML) to JSON throughout. Added content-file-to-object-model relationship, session state, skill execution model, project-export skill, JSONL audit trail. v1.0 (2026-04-12): Platform renamed from StoryEngine to ShopFloor (vertical-agnostic platform layer). Added organizational architecture: Roles, Stations, Teams (Section 13). Added Quality Control: Scorecards, Outcome Tracking, Feedback Loop (Section 14). Added Bottleneck Analysis (Section 19). Added Operations data structures (Role_Record, Scorecard, Team_Manifest). Added routing skill and scorecard-updater skill to floor management. Updated all paths from .storyengine/ to .shopfloor/. Replaced StoryEngine references with ShopFloor for platform-level concepts. StoryEngine retained as the fiction vertical name. Added Design Principle 2.8 (Organizational Clarity). v1.1 (2026-04-14): Particle redesigned — particle is now a tag on a file (isParticle: true in per-file metadata), not a standalone object-model entity. PRT IDs eliminated. Status lifecycle expanded to raw → considered → developing → placed (shelved as lateral exit). Five-role team structure locked: acquisitions-editor, publisher, developmental-editor, proofreader, managing-editor. Story Keeper renamed Managing Editor. Continuity Guard eliminated, absorbed into Proofreader. Section 6.2.1 rewritten. Section 13.5 team-manifest.json updated to five roles. Section 13.6 updated to Managing Editor. Section 17 layout updated with Inbox directories and five role directories. Section 20 open questions #1, #3, #4, #10 closed. Section 21 handoff notes updated to current priority order.*

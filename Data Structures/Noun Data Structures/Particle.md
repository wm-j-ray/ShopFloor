---
schema_type: particle_metadata
category: noun
template_version: "2.0"
profile_version: ""
date_instantiated: ""
status: template
linked_schemas:
  - Character_Profile
  - Scene_Container
  - Wound_Profile
  - Location_Profile
  - Starting_Lineup
narrative_threads: []
---

# Particle (Per-File Metadata Fields)

> **What a particle is:** A particle is a tag on a file. Not a separate data structure. Not a JSON record in `object-model/`. When Karen says "this might be something," ShopFloor sets `isParticle: true` in the file's existing per-file metadata record in `.shopfloor/files/[UUID].json`. The file itself stays where Karen put it — her inbox notebook, her cybercrime notebook, wherever. ShopFloor doesn't move it or copy it. It just notes: *this file has been elevated.*
>
> **"Show me my particles"** is a filtered view. Show all files where `isParticle: true`. A lens on existing files, not a separate data store.
>
> **This is NOT a macOS tag.** Nothing to do with Finder colored labels. `isParticle` is a field in a hidden JSON file Karen never sees.
>
> **Particle fields live in** `.shopfloor/files/[UUID].json` — the per-file metadata record that already exists for every file. Particle enrichment is optional fields added to that record when Karen promotes a file.

> **Instance naming:** No separate instance files. These fields are added to the existing `[UUID].json` record in `.shopfloor/files/`.

---

## Particle Promotion Fields

> These fields are added to the per-file metadata record when `isParticle` is set to `true`. All are optional except `isParticle` and `particleStatus`.

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

### Field Definitions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `isParticle` | boolean | yes | The tag. `true` means this file has been elevated to particle status |
| `particleStatus` | string (enum) | yes | Current status in the particle lifecycle (see below) |
| `resonanceNote` | string | no | Karen's note added at the moment of promotion — while the recognition is sharp. The *why* of the promotion, not the *what* |
| `captureMethod` | string (enum) | no | How the content originally entered the system |
| `sourceApp` | string (open) | no | App that sent the content. Auto-populated for `share_sheet` captures. Never hardcoded to known apps — any app, any future app |
| `sourceURL` | string | no | Link to original article, clip, IMDB entry, etc. |
| `sourceType` | string (enum) | no | Category of source material |
| `linkedEntities` | array | no | Entity IDs linked to this particle (e.g., `["CHR-001", "WND-002"]`) |
| `linkedStartingLineup` | string | no | ID of the Starting Line-Up this particle contributed to, once placed |
| `lastSurfaced` | string (date) | no | Last time the system returned this particle in a query result |
| `surfaceCount` | integer | no | Number of times this particle has appeared in resurfacing results |

---

## Capture Method Enum (closed)

| Value | Meaning |
|-------|---------|
| `share_sheet` | iOS Share Sheet from any external app — primary mobile capture path |
| `direct` | Typed or spoken directly in-app by Karen |
| `import` | Pulled from an external data source via structured extract (batch) |
| `sync` | Ingested from a connected vault or note system (ongoing) |
| `manual` | Pasted, dragged in, or file-dropped via Files picker |
| `promoted` | File already existed in Karen's notebooks; she elevated it to particle status |

`sourceApp` is an open string, never part of the enum. Never hardcode app names.

---

## Source Type Enum (open — AI infers, Karen can override)

`own_writing` / `collected_quote` / `film_reference` / `craft_note` / `overheard` / `observed_scene` / `lyric_or_poetry` / `unknown`

---

## Status Lifecycle

`raw → considered → developing → placed`

`shelved` is a lateral exit from any state except `placed`.

| Status | Meaning |
|--------|---------|
| `raw` | Promoted but not yet engaged with |
| `considered` | Karen engaged — resonance note added, or entity pre-assigned at capture |
| `developing` | Karen is actively working this toward a Starting Line-Up |
| `placed` | Incorporated into an active project (linked to a Starting Line-Up or greenlit work) |
| `shelved` | Intentionally set aside — can be retrieved at any time |

**How initial status is set:**

| Engagement at promotion | Status at save |
|------------------------|----------------|
| Nothing — promoted without engagement | `raw` |
| Resonance note added | `considered` |
| Entity pre-assigned | `considered` |
| Both note and entity | `considered` |

Status advances are logged to the audit trail. Tap the status indicator to advance.

---

## File Protection

Karen is fully protected when she renames or moves files. The UUID never changes. The per-file metadata record updates `currentFilename` and `relativePath` automatically via the self-healing rename detection system. The particle tag follows the file silently.

No Karen action is required. No particle is ever lost to a rename or move.

---

## Notes

*No notes yet.*

---
schema_type: revelation_log
category: verb
vertical: storyengine
template_version: "1.1"
profile_version: ""
date_instantiated: ""
status: template
priority: 2
linked_schemas:
  - Scene_Container
  - Character_Profile
  - Plot_Thread_Tracker
  - Continuity_Log
writable_by:
  - developmental_editor
  - proofreader
narrative_threads: []
---

# Revelation Log

> **Purpose:** Tracks what information is withheld from whom — character or reader — and maps when and how it is released across the story.
>
> **Instance naming:** When creating an instance, save as `[ID]_Name.md`, set `profile_version` and `date_instantiated`.

> 🟡 **TIER 2 — Important.** Complete after core Tier 1 structures are established.

---

## Identity

| Field | Value |
|-------|-------|
| Working Title of Work |  |
| Last Updated |  |

## Revelation Registry

| Field | Value |
|-------|-------|
| Entry fields per revelation (one row per withheld fact) |  |

| Rev ID | The Hidden Fact | Hidden From [Character ID(s) | reader | both] | Established In [Scene ID] | Released In [Scene ID] | Release Method | Narrative Purpose |
|---|---|---|---|---|---|---|---|---|

## Release Method Key

direct        = stated plainly in dialogue or narration
indirect      = implied through behavior or context
discovered    = character finds physical evidence
confessed     = character admits voluntarily
forced        = character admits under pressure
dramatic irony = reader knows; character does not

## Revelation Registry

| [Rev ID | Hidden Fact | Hidden From | Established In | Released In | Release Method | Narrative Purpose] |
|---|---|---|---|---|---|---|

## Structural Flags

| Field | Value |
|-------|-------|
| Revelations Released Too Early (before reader investment is sufficient) | Rev ID(s) |
| Revelations Released Too Late (reader has stopped caring or guessed) | Rev ID(s) |
| Revelations Never Released (intentional or accidental) | Rev ID(s) |
| Contradictions Between What Characters Know and What They Do | `Character ID` / `Scene ID` |

## Notes

*No notes yet.*

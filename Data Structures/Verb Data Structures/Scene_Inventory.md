---
schema_type: scene_inventory
category: verb
template_version: "1.2"
profile_version: ""
date_instantiated: ""
status: template
priority: 1
linked_schemas:
  - Scene_Container
  - Character_Profile
  - Location_Profile
  - POV_Profile
narrative_threads: []
---

# Scene Inventory

> **Purpose:** Master index of all Scene Containers in a work of fiction, sequenced and tagged for navigation, status tracking, and structural oversight.
>
> **Instance naming:** When creating an instance, save as `[ID]_Name.md`, set `profile_version` and `date_instantiated`.

> 🔴 **TIER 1 — Core engine.** Complete before drafting begins.

---

## Identity

| Field | Value |
|-------|-------|
| Working Title of Work |  |
| Manuscript Total Word Count (working target) |  |
| Total Scene Count (running) |  |
| Last Updated |  |

## Index Format

| Field | Value |
|-------|-------|
| Entry fields per scene (one row per scene) |  |

| Scene ID | Scene Label | Chapter | POV Character ID | Location ID | In-World Date | Draft Status | Function Type | Conflict ID(s) | Scene Word Count | Running Word Count | MS Position % | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|

## Field Definitions

| Field | Value |
|-------|-------|
| Scene Word Count | Word count of this scene only |
| Running Word Count | Cumulative word count at end of this scene |

MS Position %:       (Running Word Count / Manuscript Total Word Count) x 100
Used to verify beat target positions against Framework percentages

## Scene Index

| [Scene ID | Scene Label | Chapter | POV Character ID | Location ID | In-World Date | Draft Status | Function Type | Conflict ID(s) | Scene Word Count | Running Word Count | MS Position % | Notes] |
|---|---|---|---|---|---|---|---|---|---|---|---|---|

## Status Key

outline    = structure defined, no prose
draft      = first prose written
revised    = at least one revision pass complete
locked     = no further changes without explicit decision

## Function Type Key

exposition     = world or character information delivered
escalation     = conflict intensified
reversal       = expectation or situation inverted
revelation     = withheld information released
confrontation  = direct clash between characters or forces
transition     = movement between states or locations
resolution     = conflict closed or partially closed

## Structural Flags

| Field | Value |
|-------|-------|
| Scenes Without a Clear Function Type |  |
| POV Imbalances (one Character ID over- or under-represented) |  |
| Location Clusters (too many consecutive scenes at same Location ID) |  |
| Pacing Flags (long stretches without escalation or reversal) |  |
| Continuity Risks (scenes that depend on unresolved upstream facts) |  |

| Beats Whose MS Position % Falls Outside Framework Target Range: [Beat ID | actual % | target %] |
|---|---|---|

## Notes

*No notes yet.*

---
schema_type: thread_registry
category: scaffolding
template_version: "1.0"
profile_version: ""
date_instantiated: ""
status: template
priority: 2
linked_schemas:
  - Story_Spine
  - Plot_Thread_Tracker
  - Subplot_Profile
  - Scene_Container
writable_by:
  - developmental_editor
  - proofreader
narrative_threads: []
---

# Thread Registry

> **Purpose:** Master registry of all Narrative Thread tags used across project files — defines each tag, its scope, and prevents tag drift through a controlled vocabulary.
>
> **Instance naming:** When creating an instance, save as `[ID]_Name.md`, set `profile_version` and `date_instantiated`.

> 🟡 **TIER 2 — Important.** Complete after core Tier 1 structures are established.

---

## Identity

| Field | Value |
|-------|-------|
| Working Title of Work |  |
| Last Updated |  |
| Total Tags Registered |  |

## Registry Format

| Tag ID | Tag Label | Tag Type | Definition | Scope | Files Where Active | Status |
|---|---|---|---|---|---|---|

One row per tag. All fields required when registering a new tag.

## Field Definitions

| Field | Value |
|-------|-------|
| Tag ID | Unique identifier THR-001, THR-002, ... |
| Tag Label | The exact string used in Narrative Threads fields across all files |
| Tag Type | `plot` / `character` / `thematic` / `relational` / `structural` / `other` |
| Definition | One sentence — what this thread tracks or signals |
| Scope | `global` / `act-1` / `act-2` / `act-3` / `subplot` / `other` |
| Files Where Active | List of file names where this tag appears |
| Status | `active` / `dormant` / `resolved` / `retired` |

Must be lowercase, hyphenated, no spaces [e.g., revenge-arc, found-family]

## Tag Type Key

plot       = tracks an external narrative event or pursuit across scenes
character  = tracks a character's internal arc or behavioral pattern
thematic   = marks scenes or profiles that carry a specific thematic argument
relational = tracks the dynamic between two specific characters
structural = marks a structural function (e.g., a beat cluster or act boundary)
other      = anything that does not fit above categories

## Tag Registry

| [Tag ID | Tag Label | Tag Type | Definition | Scope | Files Where Active | Status] |
|---|---|---|---|---|---|---|

## Governance Rules

1. No new tag may be used in any file until it is registered here first.
2. Tag Labels must be exact — case, spacing, and hyphenation must match
across every file that uses them. Variants of the same tag are separate
entries and must be explicitly linked in the Definition field.
3. When a thread resolves or is retired, update its Status here and in all
files where it appears.
4. Tag drift check: run a search across all project files for any Narrative
Threads value not present in this registry. Unregistered tags should be
added or normalized immediately.

## Drift Check Log

| Date | Unregistered Tag Found | Found In | Action Taken: |
|---|---|---|---|

## Notes

*No notes yet.*

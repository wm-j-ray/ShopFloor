---
schema_type: beat_registry
category: scaffolding
template_version: "1.1"
profile_version: ""
date_instantiated: ""
status: template
priority: 1
linked_schemas:
  - Story_Spine
  - Framework_Selector
  - Conformance_Report
  - Scene_Container
narrative_threads: []
---

# Beat Registry

> **Purpose:** Master record of every structural beat in the chosen framework — tracking location, status, and conformance for each beat across the full manuscript.
>
> **Instance naming:** When creating an instance, save as `[ID]_Name.md`, set `profile_version` and `date_instantiated`.

> 🔴 **TIER 1 — Core engine.** Complete before drafting begins.

---

## Identity

| Field | Value |
|-------|-------|
| Working Title of Work |  |
| Framework Applied | link to Framework_Selector |
| Total Beats Required by Framework |  |
| Total Beats Registered |  |
| Last Updated |  |

## Beat Entry Format

| Beat ID | Beat Label | Required | Act | Target Position | Scene ID | Scene Label | Draft Status | Conformance Flag | Notes |
|---|---|---|---|---|---|---|---|---|---|

One row per beat. All fields required.

## Field Definitions

| Field | Value |
|-------|-------|
| Beat ID | Unique identifier BT-001, BT-002, ... |
| Beat Label | Name of the beat as defined by the Framework |
| Required | yes, no — whether the Framework mandates this beat |
| Act | Which act this beat belongs to 1, 2, 3, other |
| Target Position | Approximate location in manuscript % of total or word count range |
| Scene ID | Link to Scene_Container [[SCN-001]] — primary join key |
| Scene Label | Label of the Scene Container where this beat occurs |
| Draft Status | `outline` / `draft` / `revised` / `locked` |
| Conformance Flag | `present` / `absent` / `weak` / `conflicted` / `deferred` |
| Notes | Free text — craft observations, problems, decisions |

## Conformance Flag Key

present    = beat exists and functions as the framework requires
absent     = beat has not been written or placed
weak       = beat exists but does not carry sufficient weight or clarity
conflicted = beat contradicts another beat or continuity fact
deferred   = beat intentionally delayed; documented reason required in Notes

## Beat Registry

| [Beat ID | Beat Label | Required | Act | Target Position | Scene ID | Scene Label | Draft Status | Conformance Flag | Notes] |
|---|---|---|---|---|---|---|---|---|---|

## Summary Counts

| Field | Value |
|-------|-------|
| Required Beats Total |  |
| Required Beats Present |  |
| Required Beats Absent |  |
| Required Beats Weak |  |
| Required Beats Conflicted |  |
| Optional Beats Total |  |
| Optional Beats Present |  |
| Conformance Score (auto or manual) | link to Conformance_Report |

## Notes

*No notes yet.*

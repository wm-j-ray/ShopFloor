---
schema_type: structural_gap_log
category: scaffolding
vertical: storyengine
template_version: "1.1"
profile_version: ""
date_instantiated: ""
status: template
priority: 2
linked_schemas:
  - Conformance_Report
  - Beat_Registry
  - Scene_Container
  - Arc_Beat_Sheet
writable_by:
  - developmental_editor
narrative_threads: []
---

# Structural Gap Log

> **Purpose:** Running record of missing, weak, or conflicted beats identified during conformance grading — with diagnosis, recommended action, and resolution status.
>
> **Instance naming:** When creating an instance, save as `[ID]_Name.md`, set `profile_version` and `date_instantiated`.

> 🟡 **TIER 2 — Important.** Complete after core Tier 1 structures are established.

---

## Identity

| Field | Value |
|-------|-------|
| Working Title of Work |  |
| Framework Applied | link to Framework_Selector |
| Last Updated |  |

## Gap Entry Format

| Gap ID | Beat ID | Beat Label | Scene ID | Gap Type | Diagnosis | Recommended Action | Priority | Status | Date Resolved |
|---|---|---|---|---|---|---|---|---|---|

One row per identified gap.

## Field Definitions

| Field | Value |
|-------|-------|
| Gap ID | Unique identifier GAP-001, GAP-002, ... |
| Beat ID | Link to Beat_Registry entry [[BT-001]] |
| Beat Label | Name of the beat as defined by the Framework |
| Scene ID | Scene where gap is located or should be located [[SCN-001]], none |
| Gap Type | `absent` / `weak` / `conflicted` / `misplaced` / `deferred-unresolved` |
| Diagnosis | What specifically is wrong or missing |
| Recommended Action | Concrete next step to resolve the gap |
| Priority | `critical` / `high` / `moderate` / `low` |
| Status | `open` / `in progress` / `resolved` / `accepted-deviation` |
| Date Resolved | `YYYY-MM-DD` / `pending` |

## Gap Type Key

absent              = beat has not been written or placed
weak                = beat exists but lacks weight, clarity, or consequence
conflicted          = beat contradicts another beat or established fact
misplaced           = beat exists but occurs at the wrong point in the structure
deferred-unresolved = beat was marked deferred but no resolution has been documented

## Priority Key

critical  = required beat; absence significantly reduces conformance score
high      = required beat; absence weakens a major structural hinge
moderate  = optional beat; absence reduces score but does not break structure
low       = minor beat; absence noted for awareness only

## Gap Registry

| [Gap ID | Beat ID | Beat Label | Scene ID | Gap Type | Diagnosis | Recommended Action | Priority | Status | Date Resolved] |
|---|---|---|---|---|---|---|---|---|---|

## Summary

| Field | Value |
|-------|-------|
| Total Open Gaps |  |
| Critical Gaps Open |  |
| High Gaps Open |  |
| Gaps Resolved This Pass |  |
| Gaps Accepted as Intentional Deviation |  |

## Notes

*No notes yet.*

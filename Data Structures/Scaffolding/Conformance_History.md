---
schema_type: conformance_history
category: scaffolding
template_version: "1.1"
profile_version: ""
date_instantiated: ""
status: template
priority: 3
linked_schemas:
  - Conformance_Report
  - Beat_Registry
  - Structural_Gap_Log
  - Story_Spine
narrative_threads: []
---

# Conformance History

> **Purpose:** Versions the conformance score across drafts so the writer can track structural improvement over time.
>
> **Instance naming:** When creating an instance, save as `[ID]_Name.md`, set `profile_version` and `date_instantiated`.

> 🟢 **TIER 3 — Revision tool.** Most useful after a complete draft exists.

---

## Identity

| Field | Value |
|-------|-------|
| Working Title of Work |  |
| Framework Applied | link to Framework_Selector |

## History Entry Format

| Entry ID | Date | Draft Stage | RBS | OBS | Penalty | Overall Score | Band | Gaps Open | Gaps Resolved | Key Change | Report Link |
|---|---|---|---|---|---|---|---|---|---|---|---|

One row per Conformance Report run.

## Field Definitions

| Field | Value |
|-------|-------|
| Entry ID | Unique identifier CH-001, CH-002, ... |
| Date |  |
| Draft Stage | `outline` / `first draft` / `revision 1` / `revision 2` / `other` |
| RBS | Required Beat Score (0-100) |
| OBS | Optional Beat Score (0-100) |
| Penalty | Problem penalty applied (negative integer) |
| Overall Score | Final conformance score (0-100) |
| Band | `90-100` / `75-89` / `60-74` / `45-59` / `below 45` |
| Gaps Open | Number of open gaps at time of report |
| Gaps Resolved | Number of gaps resolved since prior report |
| Key Change | Most significant structural change made since last report |
| Report Link | Link to the Conformance_Report instance for this entry |

## Conformance History

| [Entry ID | Date | Draft Stage | RBS | OBS | Penalty | Overall Score | Band | Gaps Open | Gaps Resolved | Key Change | Report Link] |
|---|---|---|---|---|---|---|---|---|---|---|---|

## Trend Analysis

| Field | Value |
|-------|-------|
| Highest Score Achieved |  |
| Lowest Score Recorded |  |
| Current Trajectory | `improving` / `stable` / `declining` |
| Biggest Single-Pass Improvement | `Entry ID` / `score delta` / `what changed` |
| Most Persistent Gap | `Beat ID` / `Beat Label` / `how many passes it has remained open` |

## Notes

*No notes yet.*

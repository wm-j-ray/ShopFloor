---
schema_type: conformance_report
category: scaffolding
template_version: "1.1"
profile_version: ""
date_instantiated: ""
status: template
priority: 1
linked_schemas:
  - Beat_Registry
  - Framework_Selector
  - Story_Spine
  - Structural_Gap_Log
narrative_threads: []
---

# Conformance Report

> **Purpose:** Grades a manuscript's structural conformance against the chosen framework — scoring required and optional beats, flagging problems, and tracking improvement across drafts.
>
> **Instance naming:** When creating an instance, save as `[ID]_Name.md`, set `profile_version` and `date_instantiated`.

> 🔴 **TIER 1 — Core engine.** Complete before drafting begins.

---

## Identity

| Field | Value |
|-------|-------|
| Working Title of Work |  |
| Framework Applied | link to Framework_Selector |
| Draft Stage | `outline` / `first draft` / `revision 1` / `revision 2` / `other` |
| Report Date |  |
| Graded By | `author` / `AI` / `editor` / `other` |

## Scoring Methodology

| Field | Value |
|-------|-------|
| Required Beat Score | (Required Beats Present / Required Beats Total) x 100 = RBS |
| Optional Beat Score | (Optional Beats Present / Optional Beats Total) x 100 = OBS |
| Problem Penalty | -5 per conflicted beat / -3 per weak beat |
| Overall Conformance Score | RBS weighted 70% + OBS weighted 30% - Problem Penalty |

## Score Thresholds

90-100   = Structurally complete — framework fully honored
75-89    = Substantially complete — minor gaps only
60-74    = Partial conformance — key beats missing or weak
45-59    = Significant structural gaps — major revision needed
below 45 = Framework not yet applied — early stage or custom path

## Required Beat Summary

| Beat ID | Beat Label | Scene ID | Conformance Flag | Problem Description (if any): |
|---|---|---|---|---|

## Optional Beat Summary

| Beat ID | Beat Label | Scene ID | Conformance Flag | Problem Description (if any): |
|---|---|---|---|---|

## Score Calculation

| Field | Value |
|-------|-------|
| Required Beats Total |  |
| Required Beats Present |  |
| Required Beat Score (RBS) |  |
| Optional Beats Total |  |
| Optional Beats Present |  |
| Optional Beat Score (OBS) |  |
| Conflicted Beats Count |  |
| Weak Beats Count |  |
| Problem Penalty Total |  |
| Overall Conformance Score |  |
| Score Threshold Band | `90-100` / `75-89` / `60-74` / `45-59` / `below 45` |

## Diagnostic Summary

| Field | Value |
|-------|-------|
| Top Three Structural Problems |  |
| Recommended Next Actions |  |
| Linked Gap Log | link to Structural_Gap_Log |

## Version History

| Report Version | Date | Draft Stage | Overall Score | Key Change From Prior Version: |
|---|---|---|---|---|

## Notes

*No notes yet.*

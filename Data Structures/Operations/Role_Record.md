---
schema_type: role_record
category: operations
vertical: platform
template_version: "1.0"
profile_version: ""
date_instantiated: ""
status: template
linked_schemas:
  - Scorecard
  - Team_Manifest
writable_by:
  - managing_editor
narrative_threads: []
---

# Role Record

> **Purpose:** Tracks the per-project history of a single role — what it has done, what's pending, and when it was last active. This is the role's resume for a specific project. One record per role per project.
>
> **Instance naming:** `Role_Record_[ROLE_ID].json` (e.g., `Role_Record_DEV_EDITOR.json`). Role IDs are uppercase with underscores, matching the ROLE.md directory name convention.

> 🔧 **OPERATIONS — Floor Management.** Updated automatically by session-init and session-end skills. Not directly invoked by Karen.

---

## Identity

| Field | Value |
|-------|-------|
| Role ID | |
| Role Name | |
| Project ID | (container UUID of the project this record belongs to) |
| Team ID | (from Team_Manifest — identifies which vertical installed this role) |

---

## Activity Summary

| Field | Value |
|-------|-------|
| Last Active | (ISO 8601 timestamp) |
| Session Count | (total sessions where this role was activated) |
| Total Skills Invoked | (count of all skill invocations across all sessions) |
| Last Skill Used | (skill ID of most recent invocation) |

---

## Work History

### Entities Created

> Populated automatically as skills in this role create object model entities.

| Entity ID | Entity Type | Date Created |
|-----------|-------------|-------------|
| | | |

### Chapters / Content Reviewed

> Populated automatically when skills in this role reference content files.

| File UUID | Display Name | Date Reviewed |
|-----------|-------------|---------------|
| | | |

---

## Open Flags

> Issues this role has identified but not yet resolved. Populated by Tier 2 quality control skills and Tier 3 production skills.

| Flag | Severity | Date Flagged | Source Skill |
|------|----------|-------------|-------------|
| | `critical` / `moderate` / `minor` | | |

---

## Conformance Notes

> AI-generated observations about this role's coverage and gaps. Updated by the conformance-reporter skill.

*No conformance notes yet.*

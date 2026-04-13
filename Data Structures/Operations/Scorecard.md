---
schema_type: scorecard
category: operations
template_version: "1.0"
profile_version: ""
date_instantiated: ""
status: template
linked_schemas:
  - Role_Record
  - Team_Manifest
narrative_threads: []
---

# Scorecard

> **Purpose:** Per-role, per-project performance summary derived from the audit trail. Tracks how often a role's skills are invoked and how Karen responds to their output — accepted, modified, or ignored. This is how the floor knows which stations are producing good work and which need attention.
>
> **Instance naming:** `Scorecard_[ROLE_ID].json` (e.g., `Scorecard_DEV_EDITOR.json`). One per role per project.

> 🔧 **OPERATIONS — Quality Control.** Updated incrementally by the scorecard-updater skill (Tier 1) after each SKILL_OUTCOME event. Can be fully recomputed from the audit trail if drift is detected.

---

## Identity

| Field | Value |
|-------|-------|
| Role ID | |
| Role Name | |
| Project ID | (container UUID) |

---

## Evaluation Configuration

> Controls when and how Karen is prompted to evaluate skill output. Configurable at system, role, and skill level. Skill-level settings override role-level, which override system defaults.

| Field | Value |
|-------|-------|
| Role-level Evaluation Mode | `warranty` / `active` / `passive` |
| Warranty Target | (default: 10 invocations — configurable) |
| Warranty Complete | `true` / `false` |
| Active Mode Frequency | (prompt Karen every N uses — default: 3) |

> **Evaluation modes:**
> - `warranty` — newly installed skill; prompt Karen after every use until warranty target is reached; then transition to the system/role default
> - `active` — prompt Karen every N uses (configurable); use is never invisible
> - `passive` — no prompting; track accept/modify/ignore behavior naturally through observation only
>
> **Warranty period:** The first N uses of a skill are its most informative. A new skill hasn't earned trust yet. During warranty, feedback is always solicited — but it must be lightweight. Not a survey. A single tap: 👍 / 👎 / "tell me more." Karen answers in two seconds or skips. Either way, the system learns.
>
> **After warranty:** The skill transitions to the role's default mode. If the skill's acceptance rate during warranty is below the quality threshold (configurable in `system-manifest.json`), the floor flags it for Bill's attention before the transition.

---

## Skill Evaluation Configuration

> Per-skill evaluation mode. Skills inherit the role-level mode unless overridden here.

| Skill ID | Evaluation Mode | Warranty Target | Warranty Complete | Active Frequency |
|----------|----------------|-----------------|-------------------|-----------------|
| | | | | |

---

## Aggregate Performance

| Field | Value |
|-------|-------|
| Total Invocations | |
| Accepted | (count) |
| Modified | (count) |
| Ignored | (count) |
| Acceptance Rate | (accepted / total) |
| Modification Rate | (modified / total) |
| Ignored Rate | (ignored / total) |

---

## Skill Breakdown

> Performance per skill within this role. Identifies which specific skills are strong and which need refinement. **Invocation count is the primary health signal** — a skill that isn't being used is telling you something, regardless of its acceptance rate.

| Skill ID | Invocations | Accepted | Modified | Ignored | Acceptance Rate | In Warranty |
|----------|------------|----------|----------|---------|----------------|-------------|
| | | | | | | |

---

## Trend (Last 5 Sessions)

> Rolling window to detect improvement or degradation over time. Populated automatically.

| Session Date | Skills Run | Accepted | Modified | Ignored |
|-------------|-----------|----------|----------|---------|
| | | | | |

---

## Integrity

| Field | Value |
|-------|-------|
| Last Updated | (ISO 8601 timestamp) |
| Last Audit Event Processed | (ISO 8601 timestamp — pointer into audit.jsonl) |
| Integrity Status | `current` / `stale` / `rebuilding` |

> **Staleness detection:** If `Last Audit Event Processed` is earlier than the most recent SKILL_OUTCOME event in audit.jsonl for this role, the scorecard is stale. Self-healing (Section 11.1 of the ShopFloor spec) triggers a full recompute.

---

## Notes

*No notes yet.*

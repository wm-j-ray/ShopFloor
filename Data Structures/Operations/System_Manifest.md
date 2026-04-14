---
schema_type: system_manifest
category: operations
template_version: "1.0"
profile_version: ""
date_instantiated: ""
status: template
linked_schemas:
  - Team_Manifest
  - Project
  - Scorecard
writable_by:
  - managing_editor
narrative_threads: []
---

# System Manifest

> **Purpose:** Runtime platform state and quality control configuration for this ShopFloor installation. Tracks state that changes as Karen uses the system — not role or skill definitions. Distinct from `team-manifest.json`, which is team configuration.
>
> **Instance location:** `.shopfloor/system-manifest.json` (singleton per installation).
>
> **Written by:** Managing Editor only (scorecard-updater, session-init). Read by Publisher (capacity gate) and scorecard-updater (evaluation thresholds).

> 🔧 **OPERATIONS — Runtime State.** Updated after skill outcomes and session events. Never written directly by Karen.

---

## JSON Schema

```json
{
  "schema_version": "1.0",
  "date_instantiated": "",
  "last_modified": "",
  "active_project_count": 0,
  "quality_control": {
    "warranty_target": 10,
    "modification_threshold": 0.40,
    "publisher_warranty_greenlight_max": 0.80,
    "active_evaluation_interval": 3
  }
}
```

---

## Field Definitions

### Top-Level Fields

| Field | Type | Written by | Description |
|-------|------|-----------|-------------|
| `schema_version` | string | Managing Editor (on create) | Version of this schema. Stable until schema-migrator updates it |
| `date_instantiated` | string (ISO 8601) | Managing Editor (on create) | When this installation was initialized |
| `last_modified` | string (ISO 8601) | Managing Editor | Updated on every write |
| `active_project_count` | integer | Managing Editor (scorecard-updater) | Count of projects where `pipeline_state = greenlit`. Incremented on greenlight, decremented when a greenlit project is shelved or archived. Read by the Publisher's capacity gate |
| `quality_control` | object | Managing Editor (Bill-configured) | Evaluation thresholds — see below |

**Write access:** Managing Editor only. No other role writes to this file.

---

### Quality Control Object

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `warranty_target` | integer | `10` | Number of invocations before a skill graduates from warranty mode and transitions to the role default evaluation mode. Applies to all skills unless overridden in the Scorecard |
| `modification_threshold` | float (0.0–1.0) | `0.40` | If a skill's modification rate exceeds this value after warranty, the floor flags it for Bill's review. A skill Karen always has to fix is not performing |
| `publisher_warranty_greenlight_max` | float (0.0–1.0) | `0.80` | If the Publisher greenlights more than this fraction of pitches during its warranty period, surface a review flag to Bill. A Publisher that always says yes is not doing its job |
| `active_evaluation_interval` | integer | `3` | In active evaluation mode, prompt Karen for feedback every N invocations. Lower = more prompts = more signal, at the cost of interruption frequency |

---

## Lifecycle

`system-manifest.json` is created by session-init on first installation. It is never deleted — it travels with the installation for the lifetime of the project folder.

### active_project_count maintenance

| Event | Action |
|-------|--------|
| Publisher greenlights a Starting Line-Up | scorecard-updater increments `active_project_count` |
| A greenlit project is shelved | scorecard-updater decrements `active_project_count` |
| A greenlit project is archived | scorecard-updater decrements `active_project_count` |

`deferred` projects do **not** count toward `active_project_count`. Only `greenlit` (active development) projects count.

---

## Usage

**Publisher capacity gate:** Before rendering a greenlight decision, the Publisher reads `active_project_count` to assess whether Karen has bandwidth for a new commitment. See `greenlight-review` SKILL.md for the capacity threshold logic.

**Scorecard-updater:** Reads `quality_control` thresholds when deciding whether to transition a skill out of warranty, flag a modification rate problem, or prompt Karen for active-mode feedback.

**Bill-facing configuration:** The `quality_control` fields are Bill's levers. Karen never sees them. Bill may adjust defaults in `.shopfloor/system-manifest.json` for a specific installation. Changes take effect on the next skill outcome event.

---

## Notes

**Gap — no `completed` pipeline state:** The Project schema (v1.0) has no `completed` or `archived` resting state. Once a project is `greenlit`, it stays `greenlit` until shelved. This means `active_project_count` cannot distinguish between a project Karen is actively writing and one that has been finished and delivered. A `completed` state is needed in a future Project schema version (v2.0) to support accurate finishing-rate calculations in the Publisher's portfolio analysis.

Until then: `active_project_count` counts all `greenlit` projects regardless of activity recency. The Publisher should also read `last_active_timestamp` on project records to judge whether a nominally "active" project is actually dormant.

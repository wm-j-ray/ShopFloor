---
schema_type: project
category: operations
template_version: "1.0"
profile_version: ""
date_instantiated: ""
status: template
linked_schemas:
  - Particle
  - Starting_Lineup
  - Scorecard
writable_by:
  - acquisitions_editor
  - publisher
  - managing_editor
narrative_threads: []
---

# Project

> **What a project is:** A project is the active development unit in ShopFloor. It is created by the Acquisitions Editor when Karen brings a particle for intake. It tracks the idea through the full pipeline: from first AE intake conversation through Publisher greenlight, into active development, and on to polish or abandonment.
>
> **Karen never sees this record directly.** It is infrastructure. The Managing Editor reads it at session start to determine routing. The AE writes to it during intake. The Publisher reads it during evaluation.
>
> **Instance location:** `.shopfloor/projects/[UUID].json`
>
> **Instance naming:** Project UUID is generated at creation. The UUID is the identifier — not the title, which may change.

---

## Schema

```json
{
  "project_id": "PRJ-001",
  "uuid": "7B2F4A9C...",
  "working_title": "",
  "date_created": "",
  "last_active_timestamp": "",
  "pipeline_state": "draft",
  "active_role": "acquisitions_editor",
  "source_particle_uuids": [],
  "active_starting_lineup_id": "",
  "swain_elements": {
    "focal_character": null,
    "situation": null,
    "objective": null,
    "opponent": null,
    "threatening_disaster": null
  },
  "intent_context": {
    "why_this_idea": null,
    "why_now": null,
    "character_relationship": null
  },
  "abandonment_history": [],
  "deferred_session_count": 0,
  "publisher_decision": null,
  "publisher_decision_date": null,
  "publisher_note": null,
  "notes": ""
}
```

---

## Field Definitions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `project_id` | string | yes | Human-readable ID (e.g., `PRJ-001`). Sequential per project folder |
| `uuid` | string | yes | System-generated UUID. Stable identifier — never changes even if title changes |
| `working_title` | string | no | Karen's title for the idea. Set by AE during intake from Karen's words |
| `date_created` | string (ISO 8601) | yes | When the AE created this record |
| `last_active_timestamp` | string (ISO 8601) | yes | Updated every session in which Karen works on this project. Used for multi-project routing disambiguation |
| `pipeline_state` | string (enum) | yes | Current resting state in the pipeline — see Pipeline State Lifecycle below |
| `active_role` | string (enum) | yes | Role currently responsible for this project. Set by Managing Editor at session start based on `pipeline_state` |
| `source_particle_uuids` | array of strings | no | UUID(s) of the particle(s) this project grew from. Populated at AE intake. A project may grow from multiple particles |
| `active_starting_lineup_id` | string | no | ID of the Starting Line-Up record currently associated with this project. Null until AE produces the SLU |
| `swain_elements` | object | yes | Slot-fill tracker for the five Swain elements. Each field is null until surfaced during AE intake. AE does not produce a Starting Line-Up until all five are non-null |
| `intent_context` | object | yes | Karen's answers to three intent questions asked during AE intake. Each field null until answered. Passed to Publisher during evaluation — Publisher does not re-ask Karen |
| `abandonment_history` | array | no | Records of prior attempts at this idea, if any. Populated during AE intake. Passed to Publisher as context |
| `deferred_session_count` | integer | yes | Number of sessions since Karen last worked on this project while it was in `deferred` state. When this reaches 3, Managing Editor resurfaces the project at session start |
| `publisher_decision` | string (enum) or null | no | The Publisher's decision after Karen pitches. Null until pitched |
| `publisher_decision_date` | string (ISO 8601) or null | no | Date of Publisher decision |
| `publisher_note` | string or null | no | Publisher's specific feedback — naming exactly what must change for revise-and-resubmit, or rationale for rejection/deferral |
| `notes` | string | no | Bill-facing operational notes. Not surfaced to Karen |

---

## Swain Elements Object

Each field is `null` until surfaced by the AE during intake. The AE tracks slot-fill state here rather than in conversation context alone, enabling Karen to pause and resume across sessions without losing progress.

| Field | Swain Element | Null until |
|-------|--------------|-----------|
| `focal_character` | The single character the story belongs to | AE surfaces it in intake |
| `situation` | The world and state of affairs at story open | AE surfaces it in intake |
| `objective` | What the focal character is trying to achieve | AE surfaces it in intake |
| `opponent` | The force working against the objective | AE surfaces it in intake |
| `threatening_disaster` | What happens if the focal character fails | AE surfaces it in intake |

The AE withholds Starting Line-Up generation until all five fields are non-null — even if Karen explicitly requests early generation.

---

## Intent Context Object

| Field | Question | Null until |
|-------|---------|-----------|
| `why_this_idea` | Why did you capture this? What was the resonance moment? | AE asks during intake |
| `why_now` | Why is this the right moment to develop this idea? | AE asks during intake |
| `character_relationship` | What is your relationship to the focal character? Why do you care about this person? | AE asks during intake |

If any field remains null when Karen pitches to the Publisher, the Publisher issues revise-and-resubmit to the AE — not to Karen directly.

---

## Abandonment History Array

Each entry records one prior attempt at this idea.

```json
{
  "tried_before": true,
  "stopped_because": "Couldn't find the opponent — the story kept collapsing at the midpoint",
  "attempt_date": "2023-09",
  "attempt_label": "First draft attempt, NaNoWriMo 2023"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `tried_before` | boolean | Whether Karen has attempted this idea before |
| `stopped_because` | string or null | Karen's own words about what stopped the prior attempt |
| `attempt_date` | string (year-month) | Approximate date of prior attempt. Precision to month is sufficient |
| `attempt_label` | string or null | Optional label Karen gives the prior attempt |

If Karen has never attempted the idea, this array is empty. The AE still asks — a clean answer ("no, this is fresh") is recorded as an empty array.

---

## Pipeline State Lifecycle

Resting states only. `revise-and-resubmit` is a transient event that writes `pipeline_state` back to `draft`.

```
draft → refined → pitched → greenlit
                          → rejected
                          → deferred
                          → revise-and-resubmit (event → writes draft)
                          → shelved
```

| State | Meaning | Active Role |
|-------|---------|-------------|
| `draft` | AE is actively developing the idea with Karen. Swain slots may be incomplete | `acquisitions_editor` |
| `refined` | AE considers the Starting Line-Up submission-ready. All Swain slots filled, intent context complete | `acquisitions_editor` |
| `pitched` | Karen has submitted the Starting Line-Up to the Publisher. Awaiting decision | `publisher` |
| `greenlit` | Publisher approved. Active story development begins | `developmental_editor` |
| `rejected` | Publisher declined. Managing Editor offers Karen the choice: revise or shelve | `acquisitions_editor` (if revise) |
| `deferred` | Publisher or Karen chose not to decide right now. AE remains active but project is dormant. Resurfaces after 3 sessions without activity | `acquisitions_editor` |
| `shelved` | Intentionally set aside. Can be retrieved at any time. Does not count toward `active_project_count` | — |

`deferred` projects do **not** count toward `active_project_count` in `system-manifest.json`. Only `greenlit` projects count as active for the Publisher's capacity gate.

---

## Active Role Enum

| Value | Role |
|-------|------|
| `acquisitions_editor` | Acquisitions Editor |
| `publisher` | Publisher |
| `developmental_editor` | Developmental Editor |
| `proofreader` | Proofreader |

The Managing Editor sets `active_role` at session start by reading `pipeline_state`. It never surfaces this value to Karen.

---

## Multi-Project Routing

When Karen has multiple active projects, the Managing Editor reads `last_active_timestamp` across all project records to determine the most recently active project. If Karen's message is ambiguous, the **active role for the most recently active project** asks a single disambiguation question. The Managing Editor does not speak to Karen directly.

---

## Notes

*No notes yet.*

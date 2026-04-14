---
schema_type: starting_lineup
category: noun
template_version: "1.1"
profile_version: ""
date_instantiated: ""
status: template
linked_schemas:
  - Particle
narrative_threads: []
---

# Starting Line-Up

> **Purpose:** The pre-greenlight artifact developed by the Acquisitions Editor from one or more particles. Based on Dwight Swain's "Starting Line-Up" concept from *Techniques of the Selling Writer*. Five elements forced into two sentences reveal whether an idea has the structural bones to become a story worth writing.
>
> **Who creates it:** The Acquisitions Editor role. Karen brings a particle. The Acquisitions Editor asks questions, surfaces the five Swain elements through conversation, and drafts the two-sentence form. Karen refines. When she's satisfied, she pitches it to the Publisher for greenlight.
>
> **Instance location:** `.shopfloor/object-model/Starting_Lineup_[ID].json`
>
> **Instance naming:** `SLU-NNN` (e.g., `SLU-001`). Sequential per project.

---

## JSON Schema

```json
{
  "startingLineupID": "SLU-001",
  "working_title": "",
  "date_created": "",
  "status": "draft",
  "source_particle_uuids": [],
  "swain_elements": {
    "focal_character": null,
    "situation": null,
    "objective": null,
    "opponent": null,
    "threatening_disaster": null
  },
  "statement": null,
  "question": null,
  "ae_notes": "",
  "publisher_decision": null,
  "publisher_decision_date": null,
  "publisher_note": null,
  "linked_project": null
}
```

---

## Field Definitions

| Field | Type | Written by | Description |
|-------|------|-----------|-------------|
| `startingLineupID` | string | AE (on create) | Sequential ID, format `SLU-NNN`. Stable — never changes |
| `working_title` | string | AE | Karen's working title for the idea |
| `date_created` | string (ISO 8601) | AE | When the AE created this record |
| `status` | string (enum) | AE, Publisher | Current state — see lifecycle below |
| `source_particle_uuids` | array of strings | AE | UUID(s) of the particle(s) this grew from |
| `swain_elements` | object | AE | The five Swain elements — each null until surfaced in intake |
| `statement` | string or null | AE | The Statement sentence — null until all five elements are confirmed |
| `question` | string or null | AE | The Question sentence — null until all five elements are confirmed |
| `ae_notes` | string | AE | Acquisitions Editor's working notes — not shown to Karen directly, but available on request |
| `publisher_decision` | string (enum) or null | Publisher | `greenlit` / `rejected` / `deferred` / `revise-and-resubmit`. Null until pitched |
| `publisher_decision_date` | string (ISO 8601) or null | Publisher | Date of Publisher decision |
| `publisher_note` | string or null | Publisher | Publisher's specific feedback or rationale |
| `linked_project` | string or null | Publisher | Project UUID — populated when greenlit |

**Write access:** AE writes all fields except `publisher_decision`, `publisher_decision_date`, `publisher_note`, `linked_project`. Publisher writes only those four. Neither touches the other's fields.

---

## Swain Elements Object

All five fields are `null` until surfaced by the AE during intake. The AE withholds `statement` and `question` generation until all five are non-null — even if Karen explicitly requests the output early.

| Field | Swain Element | Definition |
|-------|--------------|-----------|
| `focal_character` | Focal Character | The single character the story belongs to — who Karen follows through the whole arc. Must be a specific person, not a type |
| `situation` | Situation | The state of affairs at the story's opening — what world the focal character inhabits, what's already unstable or wrong |
| `objective` | Objective | What the focal character is trying to accomplish — must be concrete, completable, and urgent. Flag if abstract |
| `opponent` | Opponent | The force actively working against the objective — must have agency and make decisions. Flag if passive |
| `threatening_disaster` | Threatening Disaster | What specifically happens if the focal character fails — must be concrete and worse than the current situation. The hardest slot |

---

## The Two-Sentence Output

Generated from the five elements once all are confirmed. This is what Karen pitches to the Publisher.

**Statement:**
> [Focal Character] must [Objective] despite [Opponent] or face [Threatening Disaster].

**Question:**
> Will [Focal Character] [achieve Objective] before [Threatening Disaster] occurs?

---

## Status Lifecycle

`draft → refined → pitched → greenlit / rejected / deferred`

`revise-and-resubmit` is a transient event (not a resting state) — it writes `pipeline_state` back to `draft` in the Project record. `shelved` is a lateral exit from any state.

| Status | Meaning | Set by |
|--------|---------|--------|
| `draft` | AE is actively developing — Swain slots may be incomplete | AE (on create) |
| `refined` | All five Swain elements confirmed, output generated, Karen satisfied | AE (on Karen's acceptance) |
| `pitched` | Karen has submitted to the Publisher. Awaiting decision | AE (when Karen pitches) |
| `greenlit` | Publisher approved | Publisher |
| `rejected` | Publisher declined | Publisher |
| `deferred` | Publisher or Karen chose not to decide right now | Publisher |
| `shelved` | Intentionally set aside | AE or Publisher |

---

## Notes

*No notes yet.*

# StoryEngine Spec v1.0

**Date:** 2026-04-15
**Status:** Complete
**Platform Spec reference:** §18.2 (vertical-owned concepts)

ShopFloor has no knowledge of anything in this document. This spec is the authoritative source for StoryEngine's fiction domain — what it is, how it works, and what it owns. For platform mechanics (UUID assignment, entity ID format, write-back contract, session state envelope, etc.), see the [ShopFloor Platform Spec](ShopFloor Platform Spec.md).

**Governing principle:** *Subject matter expertise is the domain of the vertical. ShopFloor knows nothing about fiction. StoryEngine knows nothing about platform internals.*

---

## 1. What StoryEngine Is

StoryEngine is a Claude-powered writing intelligence system for fiction authors. It provides AI-assisted support for the full fiction writing pipeline — from the moment something interesting catches Karen's attention through to a manuscript ready for readers.

**The author:** Karen. Non-technical. Sees notebooks and pages only. Never sees `.shopfloor/`. Never interacts with the platform layer.

**The pipeline metaphor:** A publishing house. Five professionals work on Karen's behalf. They have domains. They hand off. Quality is tracked. The author writes; the system supports.

**What StoryEngine does not do:** Write prose. Every word in the manuscript is Karen's. StoryEngine works on the craft infrastructure around the prose — structure, character, arc, consistency — so Karen's words land where they're supposed to.

---

## 2. The Fiction Pipeline

```
[Particle captured]
        ↓
  Acquisitions Editor
  "Could this be something?"
        ↓
  [Starting Line-Up produced]
        ↓
    Publisher
    "Is this worth doing now?"
        ↓
  [Greenlit / Rejected / Deferred / Revise-and-Resubmit]
        ↓ (greenlit)
  Developmental Editor
  "Does the story work? Is the structure sound? Does the character earn the change?"
        ↓
  [Structurally sound]
        ↓
    Proofreader
    "Is the execution consistent? Is anything broken?"
        ↓
  [Ready for Karen's readers]
```

The pipeline has four active stages and one recurring orchestration layer:
- **Pre-greenlight:** Acquisitions Editor + Publisher
- **Post-greenlight development:** Developmental Editor
- **Polish:** Proofreader
- **Orchestration (always active):** Managing Editor

The Managing Editor does not work at a stage — it is the hand-off mechanism between stages.

---

## 3. The Five Production Roles

Full definitions live in the ROLE.md files under `Roles/verticals/storyengine/`. This section provides the condensed picture for cross-reference.

| Role | Domain | Primary Skill | Pipeline Stage |
|------|--------|--------------|----------------|
| **Acquisitions Editor** | Raw material evaluation, particle intake, Swain Starting Line-Up | `starting-lineup` (Tier 3) | Pre-greenlight |
| **Publisher** | Greenlight decisions, portfolio judgment, resource commitment | `greenlight-review` (Tier 3) | Pre-greenlight |
| **Developmental Editor** | Story structure, character psychology, arc, beats, scene function | `character-creation`, `wound-intake`, `beat-sheet`, `scene-development` (all Tier 3) | Post-greenlight |
| **Proofreader** | Correctness, consistency, timeline integrity, voice, POV discipline | `voice-profiler` (Tier 3) | Polish |
| **Managing Editor** | Routing, scorecard tracking, skill library management, project export | `routing`, `scorecard-updater`, `skill-installer`, `project-export` (all Tier 3) | Always active |

**The fallback role:** The Developmental Editor is the default fallback when `pipeline_state` is `greenlit` and Karen's request does not match another role's routing triggers. The Managing Editor routing skill makes this determination.

**What roles do not do:** StoryEngine roles have no knowledge of platform mechanics. They do not reference `.shopfloor/` paths, registry structures, or platform events directly. The Foreman handles platform-layer operations before any StoryEngine role activates.

---

## 4. Role Routing Rules

The Managing Editor's `routing` skill makes these determinations at every session start and after every skill completion. Karen never interacts with the Managing Editor directly — it routes silently.

### 4.1 Routing Decision Matrix

| Condition | Active Role |
|-----------|------------|
| `pipeline_state` = `draft` or `refined` | Acquisitions Editor |
| `pipeline_state` = `pitched` | Publisher |
| `pipeline_state` = `greenlit` and request matches Proofreader triggers | Proofreader |
| `pipeline_state` = `greenlit` (default) | Developmental Editor |
| `pipeline_state` = `rejected` or `revise-and-resubmit` | Acquisitions Editor |
| `pipeline_state` = `deferred` | Acquisitions Editor |
| `pipeline_state` = `shelved` | Managing Editor surfaces the project; asks Karen whether to resume |

### 4.2 Routing Trigger Keywords (by role)

**Acquisitions Editor:** particle, idea, captured, found, might be something, starting line-up, pitch, developing an idea, purgatory, could this work, is there something here

**Publisher:** pitch, greenlight, should I do this, ready to pitch, is this worth writing, ready for a decision

**Developmental Editor (fallback):** character, motivation, arc, wound, backstory, psychology, structure, pacing, act, beat, midpoint, climax, scene, chapter, framework, save the cat, story grid, something's wrong but I can't find it

**Proofreader:** consistency, continuity, timeline, chronology, POV, point of view, voice, last pass, final read, polish, proofread, thread, loose end, contradiction

### 4.3 Multi-Project Disambiguation

When Karen has multiple active projects, the Managing Editor reads `last_active_timestamp` across all Project records to determine the most recently active project. If Karen's message is ambiguous (no project name mentioned, not a clear continuation), the **active role for the most recently active project** asks a single disambiguation question. The Managing Editor does not speak to Karen directly.

### 4.4 Unmet Needs

When Karen expresses something the system cannot yet do ("I wish it could..."), the Managing Editor's response is warm intake: "Tell me more about what you'd want it to do." That signal is passed to the Foreman's Skill Designer. The Managing Editor does not design skills itself.

---

## 5. Particle Extensions

The platform owns the particle mechanism (Platform Spec §5.2). StoryEngine extends it with three vertical-specific fields declared in `VERTICAL.md` under `per_file_extensions`:

| Field | Type | Written By | Purpose |
|-------|------|-----------|---------|
| `storyengine_resonanceNote` | string | Karen (at promotion) | Karen's "why" at the moment she marked this file as a particle — what struck her, in her own words. Captured once, never overwritten. Distinct from later classification notes. The Acquisitions Editor reads this first; it is the most actionable signal for intake. |
| `storyengine_linkedStartingLineup` | string | Acquisitions Editor | Entity ID of the Starting_Lineup this particle contributed to (e.g., `SLU-00001`). Null until the particle is placed into a premise. Populated by the `starting-lineup` skill. |
| `storyengine_captureEntityChips` | array of strings | Karen (at capture) | Entity IDs tagged by Karen at capture time (e.g., `["CHR-00001", "SCN-00003"]`). Mixed entity types; type is encoded in the prefix. Represents Karen's in-the-moment associations, not formal object model links. Can be empty. |

**What is not declared:** Platform particle fields (`isParticle`, `particleStatus`, `captureMethod`, `sourceApp`, `sourceURL`, `sourceType`, `lastSurfaced`, `surfaceCount`) are available to StoryEngine automatically without any declaration. They are platform infrastructure.

---

## 6. particleStatus Lifecycle in Fiction Context

The platform defines the `particleStatus` field and its four valid states plus lateral exit. StoryEngine defines what each state means in the fiction domain:

| Platform State | StoryEngine Meaning | Trigger |
|---------------|---------------------|---------|
| `raw` | Karen captured something. No StoryEngine role has touched it. The resonanceNote may be set; no formal intake has started. | Automatic at promotion |
| `considered` | An Acquisitions Editor intake conversation has begun from this particle. Swain slot-fill has started. The particle is being evaluated for story potential. | AE intake begins |
| `developing` | The particle is linked to an active Starting Line-Up in development. `storyengine_linkedStartingLineup` is set. The project is in `draft` or `refined` state. | AE writes `storyengine_linkedStartingLineup` |
| `placed` | The particle's contribution has been incorporated into the story. The project is `greenlit` and the particle's material appears in the object model (e.g., in a Character Profile, Scene Container, or beat sheet). The particle is no longer just potential — it has a home. | Developmental Editor or AE confirms placement |
| `shelved` (lateral exit) | Intentionally set aside. The particle may have been considered and found not ready, or Karen chose to pause on it. Can be retrieved at any time. Does not count as abandoned — just dormant. | Karen or AE choice |

A particle can be `placed` while the project it contributed to is still in active development. Placement is about the particle's contribution being instantiated in the object model, not about the project being complete.

---

## 7. Capture Sheet UI

StoryEngine's contribution to the capture experience is a two-layer sheet that appears when Karen promotes a file to particle status (or captures directly from the Share Sheet).

**Layer 1 — Capture:**
- Resonance note field: "What caught you? (optional)" — Karen's words, free text. Maps to `storyengine_resonanceNote`.
- Source is pre-populated from platform metadata (`sourceApp`, `sourceURL`) — Karen sees it but does not re-enter it.

**Layer 2 — Entity Chips (optional, collapsible):**
- Karen can tag the capture to existing entities in her object model.
- Shows recently used entities grouped by type (Characters, Scenes, Locations, etc.).
- Each tap adds an entity ID to `storyengine_captureEntityChips`.
- Zero required — chips are Karen's optional in-the-moment associations. She can add none and the capture is complete.
- New entities cannot be created from the capture sheet. Entity creation happens through skill conversations with the appropriate role.

**Design constraint:** The capture sheet must be completable in under 15 seconds. Layer 2 is strictly optional. The Acquisitions Editor never surfaces the capture sheet mechanics to Karen — it reads the results silently.

---

## 8. Entity Type Catalog

All 43 StoryEngine entity types. Platform entities (Scorecard, Role_Record, Team_Manifest, System_Manifest) are not listed here — they are platform-managed. Full entity prefix declarations are in `VERTICAL.md`.

### 8.1 Noun Data Structures (20 types)

| Prefix | Entity Type | What It Represents |
|--------|-------------|-------------------|
| `CHR` | Character_Profile | A character in the story world — identity, psychology, wound, voice, role in story, relationships |
| `CTG` | Conflict_Tag | An instance of conflict linking a character, a scene, and a wound activation |
| `ERA` | Era_Profile | A historical period or story-world era with its constraints and atmosphere |
| `EVT` | Event_Profile | A plot event, its participants, and its causal position in the story |
| `GRP` | Group_Profile | A named group of characters (family, faction, organization) and its dynamics |
| `LOC` | Location_Profile | A place in the story world — physical, sensory, emotional, and narrative properties |
| `MOT` | Motif_Profile | A recurring symbolic element and its intended thematic resonance |
| `NAR` | Narrator_Profile | Narrator type (first person, third limited, omniscient, etc.) and configuration |
| `OBJ` | Object_Profile | A significant object with story function, history, and symbolic weight |
| `POV` | POV_Profile | Point-of-view configuration for the story or a scene |
| `RGN` | Region_Profile | A geographic or story-world region containing multiple locations |
| `REL` | Relationship_Profile | A relationship between two characters — nature, power dynamic, history |
| `SCN` | Scene_Container | A scene — its function, participants, beats, location, and position in the story |
| `SLU` | Starting_Lineup | A Swain-model story premise artifact: five elements + Statement + Question |
| `THM` | Theme_Statement | The story's thematic argument — what the story is actually about |
| `TML` | Timeline_Entry | A chronological event entry for timeline validation |
| `VOC` | Voice_Profile | Narrative voice and style configuration — register, tone, sentence rhythm, distinctive markers |
| `WND` | Wound_Profile | A character's psychological wound — origin, false belief, behavioral consequences, triggers |
| `WTG` | Wound_Tag | A wound activation instance: where a wound fires in a specific scene |
| `PRJ` | Project | StoryEngine project state — pipeline position, starting lineup, intent context, abandonment history |

### 8.2 Verb Data Structures (10 types)

| Prefix | Entity Type | What It Represents |
|--------|-------------|-------------------|
| `ABS` | Arc_Beat_Sheet | Beat-by-beat tracking of a character's arc through the story |
| `CHP` | Chapter_Profile | A chapter — its constituent scenes, position, and structural role |
| `CNT` | Continuity_Log | A continuity fact record — what is established, where, and when |
| `PCG` | Pacing_Map | Scene-level pacing and tension tracking across the manuscript |
| `PTT` | Plot_Thread_Tracker | An open or closed plot thread — where opened, where resolved (or flagged unresolved) |
| `RAC` | Relationship_Arc | The arc of a relationship between two characters — how it changes |
| `RVL` | Revelation_Log | A plot revelation — what is revealed, when, and its structural placement |
| `SIN` | Scene_Inventory | Project-wide scene list with metadata and status |
| `SUB` | Subplot_Profile | A subplot — its scenes, arc, relationship to the main plot |
| `TPT` | Turning_Point_Tag | A structural turning point in a scene — type, function, placement |

### 8.3 Scaffolding (9 types)

| Prefix | Entity Type | What It Represents |
|--------|-------------|-------------------|
| `ACT` | Act_Profile | A story act — boundary definition, scenes within, structural requirements |
| `BRG` | Beat_Registry | Beat sheet for the active framework — beat positions, types, and manuscript placement |
| `CFB` | Custom_Framework_Builder | A user-defined story framework — Bill or Karen can define non-standard frameworks |
| `CFR` | Conformance_Report | A single framework conformance check result — pass/fail per beat |
| `CNH` | Conformance_History | History of all conformance checks for this project |
| `FWS` | Framework_Selector | The active framework selection record — which framework Karen is writing against |
| `SGL` | Structural_Gap_Log | Identified structural gaps — what is missing, where, and severity |
| `SSP` | Story_Spine | Structural spine of the story — inciting incident, midpoint, climax, resolution |
| `TRG` | Thread_Registry | Registry of all active threads and subplots — open/closed status, cross-references |

### 8.4 Frameworks (5 types)

| Prefix | Entity Type | What It Represents |
|--------|-------------|-------------------|
| `FHJ` | Framework_Heros_Journey | Hero's Journey — 12-stage monomyth template (Campbell / Vogler) |
| `FSC` | Framework_Save_The_Cat | Save the Cat — 15-beat template (Snyder) |
| `FSG` | Framework_Story_Grid | Story Grid — 5-commandments + genre conventions (Coyne) |
| `FSP` | Framework_Seven_Point | Seven Point Story Structure — hook / turn / resolution (Wells) |
| `FTA` | Framework_Three_Act | Three-Act Structure — setup / confrontation / resolution (classical) |

---

## 9. Entity Relationships

High-level relationship map. Full field-level cross-references are in each schema template.

```
Project ──────────────────────→ Starting_Lineup (active_starting_lineup_id)
    │                                  └──→ Particle (storyengine_linkedStartingLineup)
    │
    ├──→ Character_Profile ──→ Wound_Profile
    │         │                    └──→ Wound_Tag (fires in Scene)
    │         └──→ Relationship_Profile (links two CHR)
    │         └──→ Arc_Beat_Sheet
    │
    ├──→ Scene_Container ──→ Chapter_Profile ──→ Act_Profile
    │         │
    │         └──→ Location_Profile ──→ Region_Profile
    │         └──→ Conflict_Tag (CHR × Scene × WND)
    │         └──→ Turning_Point_Tag
    │         └──→ POV_Profile
    │
    ├──→ Framework_Selector ──→ [active framework instance]
    │         └──→ Beat_Registry
    │         └──→ Conformance_Report
    │
    ├──→ Plot_Thread_Tracker ──→ Thread_Registry
    │         └──→ Subplot_Profile
    │
    ├──→ Story_Spine
    ├──→ Pacing_Map
    ├──→ Continuity_Log
    ├──→ Revelation_Log
    ├──→ Scene_Inventory
    ├──→ Timeline_Entry (multiple)
    ├──→ Voice_Profile ──→ Narrator_Profile
    └──→ Theme_Statement ──→ Motif_Profile (multiple)
```

**Key relationship rules:**
- A Character_Profile can have at most one Wound_Profile (principal wound). Additional wounds are linked by reference.
- A Scene_Container belongs to exactly one Chapter_Profile; a Chapter_Profile belongs to exactly one Act_Profile.
- Framework_Selector holds exactly one active framework reference. Switching frameworks is a Managing Editor operation.
- Conformance_History accumulates Conformance_Report instances; it does not replace them.
- A Particle can contribute to at most one Starting_Lineup (`storyengine_linkedStartingLineup` is a single ID, not an array).

---

## 10. Skills Catalog

### 10.1 Existing Skills

| Skill | Role | Tier | Product Tiers | Status |
|-------|------|------|--------------|--------|
| `starting-lineup` | Acquisitions Editor | 3 | [1, 2] | Written |
| `greenlight-review` | Publisher | 3 | [1, 2] | Written |

### 10.2 Planned Skills (from ROLE.md files)

| Skill | Role | Tier | Description |
|-------|------|------|-------------|
| `character-creation` | Developmental Editor | 3 | Develop a full Character Profile through conversation |
| `wound-intake` | Developmental Editor | 3 | Develop a Wound Profile: origin, structure, behavioral consequences |
| `beat-sheet` | Developmental Editor | 3 | Map the story's beats against the active framework |
| `scene-development` | Developmental Editor | 3 | Analyze or develop a scene's structure and function |
| `character-arc-checker` | Developmental Editor | 2 | Evaluate whether a character's change is structurally sound |
| `conformance-reporter` | Developmental Editor | 2 | Check the manuscript against the active framework |
| `voice-profiler` | Proofreader | 3 | Profile Karen's narrative voice for this manuscript; detect drift |
| `timeline-validator` | Proofreader | 2 | Check scene/event chronology for consistency |
| `continuity-checker` | Proofreader | 2 | Verify facts, names, descriptions, and details are consistent |
| `thread-drift-detector` | Proofreader | 2 | Track plot threads and flag unresolved or drifting arcs |
| `routing` | Managing Editor | 3 | Match Karen's request to the appropriate StoryEngine role |
| `scorecard-updater` | Managing Editor | 3 | Record SKILL_OUTCOME and SKILL_FEEDBACK events after each skill run |
| `skill-installer` | Managing Editor | 3 | Review gate for Karen-authored skills; sync approved drafts to active Skills directory |
| `project-export` | Managing Editor | 3 | Export StoryEngine object model to human-readable markdown |

**Note:** `skill-designer` is a platform skill owned by the Foreman — not StoryEngine. It generates SKILL.md files for any role and is invoked explicitly by Bill only.

---

## 11. Session State `state` Payload

The platform envelope is defined in Platform Spec §3.2. StoryEngine defines the `state` object within that envelope.

```json
{
  "active_project_id": "PRJ-00001",
  "pipeline_state": "greenlit",
  "active_role": "developmental_editor",
  "active_skill": null,
  "swain_slots_filled": 5,
  "pending_disambiguation": false,
  "last_active_timestamp": "2026-04-15T14:32:00Z"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `active_project_id` | string or null | Entity ID of the project Karen is currently working on. Null if no project is active (e.g., first session, only shelved projects). |
| `pipeline_state` | string (enum) | The pipeline state of the active project — mirrors `pipeline_state` in the Project record. Stored here for fast session-init routing without reading the full Project record. |
| `active_role` | string (enum) | The StoryEngine role currently active for this project — set by Managing Editor routing. |
| `active_skill` | string or null | ID of a multi-turn skill currently in progress (e.g., `starting-lineup` mid-intake). Null between skill invocations. Allows sessions to resume mid-skill after interruption. |
| `swain_slots_filled` | integer | Count of non-null Swain elements in the active project (0–5). Written by the AE. Allows quick progress check without loading the full Project record. |
| `pending_disambiguation` | boolean | True if the Managing Editor routing skill is waiting for Karen to choose between multiple active projects. The active role surfaces the disambiguation question; this flag prevents routing from resolving again before Karen responds. |
| `last_active_timestamp` | string (ISO 8601) | Timestamp of last StoryEngine activity in this session. Platform uses this for multi-project routing; StoryEngine mirrors it here for consistency. |

**Lifecycle:** Session-init populates `state` from the active project's Project record. The active role updates `active_skill` and `swain_slots_filled` as work progresses. Session-close writes `state` back and clears `active_skill`.

---

## 12. Role_Record `activityLog` Payload

The platform envelope is defined in Platform Spec §4.2. StoryEngine defines the structure of entries in the `activityLog` array for each role. Every entry has a common header; the `data` object is role-specific.

**Common header (all roles):**
```json
{
  "timestamp": "2026-04-15T14:32:00Z",
  "session_id": "SES-0042",
  "skill_id": "starting-lineup",
  "event_type": "...",
  "data": {}
}
```

### 12.1 Acquisitions Editor

| `event_type` | When written | Key `data` fields |
|-------------|-------------|-------------------|
| `particle_received` | AE intake begins | `particle_uuid`, `resonance_note_present` (boolean) |
| `swain_element_surfaced` | AE extracts a Swain element | `element` (focal_character / situation / objective / opponent / threatening_disaster), `value` (text summary) |
| `intent_context_collected` | Karen answers an intent question | `field` (why_this_idea / why_now / character_relationship), `answered` (boolean) |
| `starting_lineup_created` | AE produces the two-sentence SLU | `starting_lineup_id`, `project_id`, `iteration_count` (how many drafts before Karen accepted) |
| `starting_lineup_revised` | AE revises after Publisher revise-and-resubmit | `starting_lineup_id`, `revision_number`, `what_changed` |
| `project_shelved` | Karen or AE shelves the project | `project_id`, `reason` |

### 12.2 Publisher

| `event_type` | When written | Key `data` fields |
|-------------|-------------|-------------------|
| `evaluation_started` | Publisher reads the Starting Line-Up | `starting_lineup_id`, `project_id` |
| `greenlight_decision` | Publisher renders a decision | `decision` (greenlit / rejected / deferred / revise-and-resubmit), `starting_lineup_id`, `rationale` (brief text) |
| `capacity_gate_triggered` | Karen's portfolio is at capacity | `active_project_count`, `capacity_limit`, `action_taken` (deferred or discussed) |
| `warranty_flag` | Publisher has greenlit >8 of 10 pitches in warranty period | `greenlit_count`, `total_evaluated`, `flag_surfaced_to_bill` (boolean) |

### 12.3 Developmental Editor

| `event_type` | When written | Key `data` fields |
|-------------|-------------|-------------------|
| `entity_created` | DE creates a new entity | `entity_type`, `entity_id` |
| `entity_updated` | DE updates an existing entity | `entity_type`, `entity_id`, `fields_changed` (array) |
| `structural_flag_raised` | DE identifies a structural problem | `flag_type` (pacing / act_break / missing_reversal / weak_motivation / scene_function / arc_gap), `description`, `related_entity_ids` (array) |
| `structural_flag_resolved` | A prior flag is addressed | `flag_type`, `original_flag_id`, `resolution` |
| `framework_engaged` | DE maps story against a framework | `framework_id`, `beat_count_mapped` |
| `conformance_check_run` | DE runs conformance reporter | `conformance_report_id`, `pass_count`, `fail_count` |

### 12.4 Proofreader

| `event_type` | When written | Key `data` fields |
|-------------|-------------|-------------------|
| `continuity_issue_found` | PR finds a continuity conflict | `issue_type` (name / appearance / location / fact / chronology), `description`, `scene_ids` (array), `continuity_log_id` |
| `timeline_conflict_found` | PR finds a chronology problem | `description`, `scene_ids` (array), `timeline_entry_ids` (array) |
| `voice_drift_flagged` | PR detects voice departure | `description`, `chapter_id`, `intentional` (boolean — false if unintentional) |
| `pov_violation_found` | PR finds POV break | `description`, `scene_id`, `declared_pov` |
| `thread_gap_found` | PR finds unresolved or drifting thread | `thread_id`, `description`, `plot_thread_tracker_id` |
| `structural_issue_escalated` | PR finds structural problem; escalates to DE | `description`, `referral_to` (developmental_editor), `flagged_in_scene` (entity_id) |

### 12.5 Managing Editor

| `event_type` | When written | Key `data` fields |
|-------------|-------------|-------------------|
| `routing_decision` | ME routes Karen's request | `routed_to` (role id), `trigger_matched` (keyword or phrase), `project_id` |
| `disambiguation_requested` | ME surfaced multi-project disambiguation | `project_ids` (array of candidates), `resolved` (boolean) |
| `skill_outcome_recorded` | ME records a skill outcome | `skill_id`, `outcome` (accepted / modified / ignored), `karens_note` (string or null) |
| `skill_installed` | ME activates a Karen-authored skill | `skill_id`, `source_path`, `destination_path`, `bill_approved` (boolean) |
| `project_exported` | ME exports object model | `project_id`, `export_path`, `entity_count` |
| `unmet_need_captured` | Karen expressed something the system can't do | `description`, `passed_to` (foreman_skill_designer) |

---

## 13. Object Model Record Structure

StoryEngine entity records live in `.shopfloor/storyengine/object-model/` (the `data_directory: storyengine` declaration in `VERTICAL.md` places vertical data in a scoped subdirectory).

**Naming convention:** `[EntityType]_[EntityID].json`

Examples:
```
.shopfloor/storyengine/object-model/
  Character_Profile_CHR-00001.json
  Character_Profile_CHR-00002.json
  Wound_Profile_WND-00001.json
  Scene_Container_SCN-00001.json
  Starting_Lineup_SLU-00001.json
  Project_PRJ-00001.json
```

**Schema templates vs. object model records:** The markdown files in `Data Structures/` are human-readable schema templates Karen can use as reference. The actual object model records are JSON, stored in `.shopfloor/storyengine/object-model/`, and follow the write-back contract (Platform Spec §3.3). The markdown templates document field definitions; the JSON records are operational.

**Platform envelope fields on every record:** `schemaVersion`, `profileVersion`, `dateCreated`, `dateModified`, `entityId`. These are written by the platform's write-back contract; StoryEngine skills populate the domain fields.

---

## 14. Platform Boundary Reference

This spec owns everything in Platform Spec §18.2. It does not own anything in §18.1.

The seam runs through four artifacts (Platform Spec §18.3):

1. **`VERTICAL.md`** — StoryEngine's registration contract. Platform validates it at session init.
2. **Per-file metadata** — Platform owns base fields. StoryEngine declares `storyengine_*` extensions in `VERTICAL.md`.
3. **Session state** — Platform owns the envelope (§3.2). StoryEngine owns `state` (§11 of this spec).
4. **Role_Record** — Platform owns the envelope (§4.2). StoryEngine owns `activityLog` per role (§12 of this spec).

When any placement decision is ambiguous, apply the governing principle: *subject matter expertise is the domain of the vertical.* If the question is about fiction craft — characters, scenes, wounds, structure, voice — it belongs here. If the question is about file identity, UUID management, entity ID generation, audit trails, or session mechanics — it belongs to the platform.

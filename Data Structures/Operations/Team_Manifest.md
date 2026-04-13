---
schema_type: team_manifest
category: operations
template_version: "1.0"
profile_version: ""
date_instantiated: ""
status: template
linked_schemas:
  - Role_Record
  - Scorecard
narrative_threads: []
---

# Team Manifest

> **Purpose:** Defines the team installed on this ShopFloor instance — which roles are active, which skills they own, and how incoming requests are routed to the appropriate station. The team manifest is the floor plan. It is the single document that makes the system vertical-specific.
>
> **Instance naming:** `Team_Manifest.json` (singleton per installation). Lives at the system root in `.shopfloor/team-manifest.json`.

> 🔧 **OPERATIONS — Floor Configuration.** Written once when a vertical is installed. Updated when roles or skills are added, removed, or reassigned. Read by session-init and routing skills at every session start.

---

## Team Identity

| Field | Value |
|-------|-------|
| Team ID | (e.g., `storyengine-fiction`) |
| Team Name | (e.g., `Fiction Writing Team`) |
| Vertical | (e.g., `fiction` / `legal` / `screenwriting` / `academic`) |
| Installed Date | |
| Last Modified | |

---

## Roles

> One entry per role on this team. Each role has a plain-English name, a path to its definition file, and a list of skills organized by tier.

| Role ID | Role Name | Definition Path | Tier 1 Skills | Tier 2 Skills | Tier 3 Skills |
|---------|-----------|----------------|---------------|---------------|---------------|
| | | | | | |

### StoryEngine Default Team

| Role ID | Role Name | Definition Path | Tier 1 Skills | Tier 2 Skills | Tier 3 Skills |
|---------|-----------|----------------|---------------|---------------|---------------|
| dev-editor | Developmental Editor | roles/dev-editor/ROLE.md | — | character-arc-checker, conformance-reporter | character-creation, wound-intake, beat-sheet, scene-development |
| copy-editor | Copy Editor | roles/copy-editor/ROLE.md | — | timeline-validator, continuity-checker, thread-drift-detector | voice-profiler |
| continuity-guard | Continuity Guard | roles/continuity-guard/ROLE.md | — | continuity-checker | — |
| story-keeper | Story Keeper | roles/story-keeper/ROLE.md | session-init, orphan-manager, schema-migrator, backup-restore, project-export, skill-installer, routing, scorecard-updater | — | skill-designer |

---

## Routing Configuration

| Field | Value |
|-------|-------|
| Routing Method | `keyword_match_then_clarify` |
| Fallback Role | (role ID that handles requests when no clear match — e.g., `dev-editor`) |
| Ambiguity Threshold | (0.0–1.0 — when multiple roles match above this score, ask Karen to clarify) |
| Clarification Prompt | (the question asked when routing is ambiguous) |

---

## Shared Skills

> Skills that appear in more than one role's skill list. This section documents the intentional overlap and explains why.

| Skill ID | Roles | Rationale |
|----------|-------|-----------|
| | | |

### StoryEngine Default Shared Skills

| Skill ID | Roles | Rationale |
|----------|-------|-----------|
| continuity-checker | copy-editor, continuity-guard | Copy Editor catches continuity errors during prose review. Continuity Guard runs dedicated continuity audits. Different contexts, same skill. |

---

## Notes

*No notes yet.*

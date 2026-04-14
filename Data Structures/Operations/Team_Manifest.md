---
schema_type: team_manifest
category: operations
template_version: "2.0"
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
> **Instance naming:** `team-manifest.json` (singleton per installation). Lives at the system root in `.shopfloor/team-manifest.json`.

> 🔧 **OPERATIONS — Floor Configuration.** Written once when a vertical is installed. Updated when roles or skills are added, removed, or reassigned. Read by session-init and routing skills at every session start.

---

## Team Identity

| Field | Value |
|-------|-------|
| Team ID | (e.g., `storyengine-fiction`) |
| Team Name | (e.g., `StoryEngine Fiction Team`) |
| Vertical | (e.g., `fiction` / `legal` / `screenwriting` / `academic`) |
| Installed Date | |
| Last Modified | |

---

## Roles

> Five roles constitute the StoryEngine default team. Each maps to a real-world publishing function Karen already understands. The pipeline flows left to right: idea → pitch → greenlight → development → polish.

| Role ID | Role Name | Definition Path | Tier 1 Skills | Tier 2 Skills | Tier 3 Skills |
|---------|-----------|----------------|---------------|---------------|---------------|
| | | | | | |

### StoryEngine Default Team (Locked 2026-04-14)

| Role ID | Role Name | Definition Path | Tier 1 Skills | Tier 2 Skills | Tier 3 Skills |
|---------|-----------|----------------|---------------|---------------|---------------|
| acquisitions-editor | Acquisitions Editor | roles/acquisitions-editor/ROLE.md | — | — | starting-lineup |
| publisher | Publisher | roles/publisher/ROLE.md | — | — | greenlight-review |
| developmental-editor | Developmental Editor | roles/developmental-editor/ROLE.md | — | character-arc-checker, conformance-reporter | character-creation, wound-intake, beat-sheet, scene-development |
| proofreader | Proofreader | roles/proofreader/ROLE.md | — | timeline-validator, continuity-checker, thread-drift-detector | voice-profiler |
| managing-editor | Managing Editor | roles/managing-editor/ROLE.md | session-init, orphan-manager, schema-migrator, backup-restore, project-export, skill-installer, routing, scorecard-updater | — | skill-designer |

**The pipeline:**
```
Particle → Starting Line-Up → Greenlight → Development → Polish
           Acquisitions Ed.    Publisher    Dev. Editor   Proofreader
```

**Managing Editor** runs floor infrastructure (Tier 1 skills). Invisible to Karen.

---

## Routing Configuration

| Field | Value |
|-------|-------|
| Routing Method | `keyword_match_then_clarify` |
| Fallback Role | (role ID that handles requests when no clear match — e.g., `acquisitions-editor` pre-greenlight, `developmental-editor` post-greenlight) |
| Ambiguity Threshold | (0.0–1.0 — when multiple roles match above this score, ask Karen to clarify) |
| Clarification Prompt | (the question asked when routing is ambiguous) |

---

## Shared Skills

> Skills that appear in more than one role's skill list. This section documents intentional overlap.

| Skill ID | Roles | Rationale |
|----------|-------|-----------|
| | | |

*(No shared skills in current StoryEngine default team — role boundaries are clean.)*

---

## Notes

Role structure locked 2026-04-14. Five real-world publishing roles replace the prior four generic roles (dev-editor, copy-editor, continuity-guard, story-keeper). Key change: Acquisitions Editor and Publisher are new roles not previously in the team. Continuity Guard eliminated — its responsibilities absorbed into Proofreader. Story Keeper renamed Managing Editor to sound like a real person with a real job.

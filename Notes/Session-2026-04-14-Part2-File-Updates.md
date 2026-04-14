# Session — File Updates and ROLE.md Writing
**Date:** April 14, 2026
**Session type:** Implementation of decisions from April 14 design session
**Conducted under:** gStack (office-hours)

---

## Files Updated This Session

All changes committed and pushed to GitHub (commit 5deea66).

### 1. Particle.md (v2.0 — complete rewrite)
`Data Structures/Noun Data Structures/Particle.md`

Rewrote to reflect particle-as-tag model:
- Particle is `isParticle: true` in per-file metadata — not a standalone entity
- No Content section (content IS the file)
- No PRT IDs
- Status lifecycle expanded: `raw → considered → developing → placed` (shelved as lateral exit)
- captureMethod enum adds `promoted`
- Schema shows exactly which fields are added to `.shopfloor/files/[UUID].json`

### 2. Team_Manifest.md (v2.0)
`Data Structures/Operations/Team_Manifest.md`

Updated to five-role structure:
- acquisitions-editor, publisher, developmental-editor, proofreader, managing-editor
- Old four roles (dev-editor, copy-editor, continuity-guard, story-keeper) retired
- Pipeline diagram added

### 3. ShopFloor Storage Spec (v1.1)
`Design Documents/ShopFloor Storage Spec.md`

Multiple sections updated:
- **Section 6.2.1:** Complete rewrite — particle-as-tag model, new status lifecycle, updated captureMethod enum
- **Section 13.5:** team-manifest.json example updated to five roles
- **Section 13.6:** Floor Management updated — Managing Editor replaces Story Keeper
- **Section 17:** iCloud layout updated — Inbox directories added, five role directories, updated skills list
- **Section 20:** Open questions #1 (native app), #3 (mobile runtime), #4 (update trigger), #10 (shared skills) marked CLOSED
- **Section 21:** Handoff notes updated to current priority order
- Version note updated to v1.1

### 4. Starting_Lineup.md (v1.0 — new)
`Data Structures/Noun Data Structures/Starting_Lineup.md`

New schema for Swain's Starting Line-Up artifact:
- Five Swain elements (Focal Character, Situation, Objective, Opponent, Threatening Disaster)
- Two-sentence output (Statement + Question)
- Status: draft → refined → pitched → greenlit / rejected / shelved
- Links to source particles and Publisher decision

### 5. Five ROLE.md files (new)
`Roles/[role-name]/ROLE.md` for all five roles

Each file includes: domain, responsibilities, skills (with tier), routing triggers, pipeline position, voice.

---

## What's Next (in order)

1. Generate `schema-index.json` — compressed Data Structures reference for Skill Designer
2. Generate `role-index.json` — compressed role summary for Skill Designer
3. Write `Skills/creative/starting-lineup/SKILL.md` — first proof-of-concept skill
4. Write `Skills/creative/skill-designer/SKILL.md` — the meta-skill

---

## Session Rule Reminder

Every session: conducted under gStack, decisions written to Notes/, committed and pushed.

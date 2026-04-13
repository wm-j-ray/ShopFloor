# ShopFloor — Project Brief

## What This Is

**ShopFloor** is a storage and skill orchestration platform for AI-powered creative tools.
Vertical-agnostic infrastructure — the "shop floor" that any creative vertical runs on.

**StoryEngine** is the first vertical built on ShopFloor: a Claude-powered writing
intelligence system for fiction authors.

Two metaphors govern everything:
- **The iceberg.** Karen sees her books and pages. ShopFloor is below the waterline.
- **The shop floor.** Roles work at stations. Skills are the tools. Quality control tracks what works.

## People

- **Karen** — the fiction writer. Non-technical end user. Sees books and pages only.
  Never sees `.shopfloor/`. In v2+, may describe new skills in plain English.
- **Bill** — the developer. Writes skills, defines roles, reads scorecards, improves the floor.

## Key Concepts

**Role** — named area of expertise (Developmental Editor, Copy Editor, Continuity Guard,
Story Keeper). Has plain-English responsibilities, owns skills, works at a station.

**Skill** — a `SKILL.md` file. The instruction set Claude follows when a skill is invoked.
Belongs to exactly one role. Three tiers: Tier 1 floor management, Tier 2 quality control,
Tier 3 production. Format defined in `Design Documents/Skill Designer Spec.md`.

**Particle** — the atomic unit of raw creative material. Anything captured before its
narrative function is known. Primary path: iOS Share Sheet (Stash model). Two-layer capture:
Layer 1 = instant save (zero friction), Layer 2 = optional resonance note + entity chip
(Readwise model). Schema in `Data Structures/Noun Data Structures/Particle.md`.

**Station** — the loaded context assembled for a role when active. Session-init reads the
skill's `contextFingerprint` and loads only what's declared. Context budget: 8K/10K/12K
tokens by tier.

**Scorecard** — per-role per-project performance. Tracks accepted/modified/ignored outcomes.
Warranty period (first 10 uses, configurable). Three evaluation modes: warranty → active → passive.
Schema in `Data Structures/Operations/Scorecard.md`.

**`.shopfloor/`** — hidden platform infrastructure directory inside every project folder.
Karen never sees it. Contains manifest, object model, audit trail, session state, skills cache.

## Current Status (2026-04-13)

Design phase. No code. Two foundational specs are complete:

| Document | Path | Status |
|----------|------|--------|
| ShopFloor Storage Spec v1.0 | `Design Documents/ShopFloor Storage Spec.md` | Locked |
| Skill Designer Spec v1.0 | `Design Documents/Skill Designer Spec.md` | Locked |

46 data structure schema templates live in `Data Structures/`.

## What's Next (in order)

1. Generate `schema-index.json` from Data Structures — compressed reference for Skill Designer
2. Generate `role-index.json` from Team Manifest — compressed role summary for Skill Designer
3. Write `Skills/creative/character-creation/SKILL.md` — first proof-of-concept skill
4. Write `Skills/creative/wound-intake/SKILL.md` — second proof-of-concept skill
5. Write `Skills/creative/skill-designer/SKILL.md` — the meta-skill itself
6. Resolve foundational open question: native app vs. file system as app

## Directory Structure

```
ShopFloor/
  Design Documents/     — ShopFloor Storage Spec, Skill Designer Spec, ERD, Seed Data
  Data Structures/      — 46 schema templates
    Noun Data Structures/   Character, Wound, Scene, Location, Particle, etc.
    Verb Data Structures/   Arc, Chapter, Continuity, Pacing, etc.
    Scaffolding/            Act, Beat, Conformance, Framework, etc.
    Frameworks/             Three-Act, Save the Cat, Seven Point, Story Grid, Hero's Journey
    Operations/             Role_Record, Scorecard, Team_Manifest
  Assets/               — reference graphics (NotebooksApp study)
  Skills/               — SKILL.md files (scaffolded, empty)
    system/             — Tier 1: floor management
    rules/              — Tier 2: quality control
    creative/           — Tier 3: production
    pending/            — Karen-authored skills awaiting review
  Roles/                — ROLE.md files (empty, ready)
  App/                  — future Xcode/Swift project
  Notes/                — scratch pad
```

## Important Design Decisions (do not relitigate without reason)

- Platform = **ShopFloor** (vertical-agnostic). First vertical = **StoryEngine** (fiction).
- Hidden dir = `.shopfloor/`. Product root = `StoryEngine/` in iCloud Drive.
- Capture method enum: `share_sheet / direct / import / sync / manual` (closed).
  Source app = open string auto-populated from Share Sheet metadata. Never hardcode app names.
- `note_at_capture` is distinct from later classification notes — it captures the "why" at the
  resonance moment. Status at save: nothing added → `raw`, any Layer 2 engagement → `considered`.
- Skill evaluation has three modes: `warranty` (first N uses, default 10), `active` (prompt
  every N uses, default 3rd), `passive` (observe only). Defaults live in `system-manifest.json`
  under `quality_control`.
- `SKILL_FEEDBACK` events carry a `karensNote` field — free text, optional, most actionable
  signal in the feedback system.
- The Skill Designer is Bottleneck 19.7 — most context-hungry operation. Mitigated by
  `schema-index.json` and `role-index.json` compressed indexes (not yet generated).

---

## Skill Routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken", 500 errors → invoke investigate
- Ship, deploy, push, create PR → invoke ship
- QA, test the site, find bugs → invoke qa
- Code review, check my diff → invoke review
- Update docs after shipping → invoke document-release
- Weekly retro → invoke retro
- Design system, brand → invoke design-consultation
- Visual audit, design polish → invoke design-review
- Architecture review → invoke plan-eng-review
- Save progress, checkpoint, resume → invoke checkpoint
- Code quality, health check → invoke health

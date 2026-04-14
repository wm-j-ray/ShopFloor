# ShopFloor — Project Brief

## What This Is

**ShopFloor** is a storage and skill orchestration platform for AI-powered creative tools.
Vertical-agnostic infrastructure — the "shop floor" that any creative vertical runs on.

**StoryEngine** is the first vertical built on ShopFloor: a Claude-powered writing
intelligence system for fiction authors.

Two metaphors govern everything:
- **The iceberg.** Karen sees her notebooks and pages. ShopFloor is below the waterline.
- **The shop floor.** Roles work at stations. Skills are the tools. Quality control tracks what works.

## People

- **Karen** — the fiction writer. Non-technical end user. Sees notebooks and pages only.
  Never sees `.shopfloor/`. In v2+, may describe new skills in plain English.
- **Bill** — the developer. Writes skills, defines roles, reads scorecards, improves the floor.

## Key Concepts

**Role** — named area of expertise (Acquisitions Editor, Publisher, Developmental Editor,
Proofreader, Managing Editor). Has plain-English responsibilities, owns skills, works at a station.

**Skill** — a `SKILL.md` file. The instruction set Claude follows when a skill is invoked.
Belongs to exactly one role. Three tiers: Tier 1 floor management, Tier 2 quality control,
Tier 3 production. Format defined in `Design Documents/Skill Designer Spec.md`.

**Particle** — a tag on a file. NOT a separate data structure. When Karen promotes a file
by saying "this might be something," ShopFloor adds `isParticle: true` to the file's existing
per-file metadata record in `.shopfloor/files/[UUID].json`. The file stays where Karen put it.
The particle tag follows the file through renames and moves via the UUID layer.
Status lifecycle: `raw → considered → developing → placed` (with `shelved` as lateral exit).

**Station** — the loaded context assembled for a role when active. Session-init reads the
skill's `contextFingerprint` and loads only what's declared. Context budget: 8K/10K/12K
tokens by tier.

**Scorecard** — per-role per-project performance. Tracks accepted/modified/ignored outcomes.
Warranty period (first 10 uses, configurable). Three evaluation modes: warranty → active → passive.
Schema in `Data Structures/Operations/Scorecard.md`.

**Starting Line-Up** — the pre-greenlight artifact. Developed by Acquisitions Editor from
a particle. Based on Dwight Swain's model: Focal Character + Situation + Objective + Opponent +
Threatening Disaster → two sentences (Statement + Question). Schema: Starting_Lineup.md (TBD).

**`.shopfloor/`** — hidden platform infrastructure directory inside every project folder.
Karen never sees it. Contains manifest, object model, audit trail, session state, skills cache.

## The Five Roles (Locked 2026-04-14)

| Role | Job |
|------|-----|
| **Acquisitions Editor** | Particle → Starting Line-Up. Answers: "Could this be something?" |
| **Publisher** | Go / no-go decision. Answers: "Is this worth doing now?" |
| **Developmental Editor** | Post-greenlight hard work: structure, character, arc, beats |
| **Proofreader** | Last mile: correctness, consistency, style |
| **Managing Editor** | Floor infrastructure — invisible to Karen |

**The pipeline:**
```
Particle → Starting Line-Up → Greenlight → Development → Polish
           Acquisitions Ed.    Publisher    Dev. Editor   Proofreader
```

## Product Tier Model (Locked 2026-04-14)

| Tier | Name | What Karen Gets |
|------|------|----------------|
| 0 | Stash + Readwise | Fast capture, notebooks, search, resurface. No AI needed. Free. |
| 1 | Prompt Cookbook | Same UI. App pre-cooks prompts Karen pastes into any AI. Paid one-time. |
| 2 | Hyperdrive | Same UI. Claude executes natively. Full AI. Subscription. |

**Key principle:** Roles are tier-agnostic. The Acquisitions Editor is always the Acquisitions
Editor. The tier changes the engine, not the experience. No forms ever — conversational throughout.

**Trial:** 30-day full Tier 2 access (Readwise model). Then gates kick in.

**Gillette model:** ShopFloor = razor handle. Skill packs = blades (different verticals).

## App Architecture (Locked 2026-04-14)

**Native iOS/macOS app.** The filesystem is the product. The UI makes it fast, intuitive, pretty.
Notebooks App (Alfons Schmidt) is the reference architecture. File I/O always client-side. iCloud handles sync.

Karen sees: Notebooks (folders) and documents (files). She can rename, move, sub-notebook — full control.
The inbox notebook is a first-class concept — where captures land when Karen doesn't want to decide yet.

## Current Status (2026-04-14)

Design phase. No code. Two foundational specs complete. Sessions documented in Notes/.

| Document | Path | Status |
|----------|------|--------|
| ShopFloor Storage Spec v1.0 | `Design Documents/ShopFloor Storage Spec.md` | Locked (needs role + particle updates) |
| Skill Designer Spec v1.0 | `Design Documents/Skill Designer Spec.md` | Locked |
| April 9 Office Hours | `Notes/Session-2026-04-09-Office-Hours.md` | Recovered and saved |
| April 14 Design Session | `Notes/Session-2026-04-14-Design-Session.md` | Complete |
| April 14 Roles Design | `Notes/Session-2026-04-14-Roles-Design.md` | Complete |

46 data structure schema templates live in `Data Structures/`.
5 ROLE.md files in `Roles/` (locked 2026-04-14).
1 proof-of-concept SKILL.md: `Skills/creative/starting-lineup/SKILL.md` (Tier 3, AE intake).

## What's Next (in order)

1. ~~Update Particle.md~~ — pending (particle-as-tag model not yet reflected)
2. ~~Update Team_Manifest.md~~ — pending (five new roles not yet reflected)
3. ~~Update ShopFloor Storage Spec~~ — pending (particle, roles, resolved open questions)
4. ~~Write five ROLE.md files~~ ✓ Complete (locked 2026-04-14)
5. ~~Create Starting_Lineup.md schema~~ — pending (schema exists but needs review against SKILL.md)
6. ~~Generate `schema-index.json` and `role-index.json`~~ ✓ Complete (`.shopfloor/`, 2026-04-14)
7. ~~Write first SKILL.md~~ ✓ Complete (`Skills/creative/starting-lineup/SKILL.md`, 2026-04-14)
8. ~~Write `Skills/creative/skill-designer/SKILL.md`~~ ✓ Complete (Tier 3, Managing Editor, 2026-04-14)

## Session Protocol (Mandatory — Established 2026-04-14)

**Every session must:**
1. Be conducted under gStack
2. End with decisions written to `Notes/Session-[DATE]-[TOPIC].md`
3. Commit and push to GitHub before closing
4. No exceptions. Ever.

## Important Design Decisions (do not relitigate without reason)

- Platform = **ShopFloor** (vertical-agnostic). First vertical = **StoryEngine** (fiction).
- Hidden dir = `.shopfloor/`. Product root = `StoryEngine/` in iCloud Drive.
- **Native iOS/macOS app.** Filesystem with UI frontend. NOT a web app.
- **Particle = tag on a file.** NOT a separate data structure. `isParticle: true` in per-file metadata.
- Capture method enum: `share_sheet / direct / import / sync / manual` (closed).
  Source app = open string auto-populated from Share Sheet metadata. Never hardcode app names.
- `note_at_capture` is distinct from later classification notes — captures the "why" at the resonance moment.
- Skill evaluation has three modes: `warranty` (first N uses, default 10), `active` (prompt
  every N uses, default 3rd), `passive` (observe only). Defaults live in `system-manifest.json`
  under `quality_control`.
- `SKILL_FEEDBACK` events carry a `karensNote` field — free text, optional, most actionable signal.
- The Skill Designer is Bottleneck 19.7 — most context-hungry operation. Mitigated by
  `schema-index.json` and `role-index.json` compressed indexes (not yet generated).
- Object model updates triggered by explicit skill invocation only (Open Question #4 — CLOSED).
- No forms ever. Conversational UI throughout all three product tiers.

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
  Roles/                — ROLE.md files (to be written)
  Notes/                — Session records (written at end of every session)
  App/                  — future Xcode/Swift project
```

---

## Skill Routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken" → invoke investigate
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

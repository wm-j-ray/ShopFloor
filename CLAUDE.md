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

## The Five StoryEngine Roles (Locked 2026-04-14)

These are **StoryEngine vertical roles** — domain experts in fiction. They know nothing about
platform internals.

| Role | Job |
|------|-----|
| **Acquisitions Editor** | Particle → Starting Line-Up. Answers: "Could this be something?" |
| **Publisher** | Go / no-go decision. Answers: "Is this worth doing now?" |
| **Developmental Editor** | Post-greenlight hard work: structure, character, arc, beats |
| **Proofreader** | Last mile: correctness, consistency, style |
| **Managing Editor** | StoryEngine creative floor — routes Karen to the right role. Tier 3. |

**Foreman** — ShopFloor **platform** role (NOT StoryEngine). Lives at `Roles/foreman/ROLE.md`.
Owns: vertical registration, global registry, team manifest, context index generation, halt
detection, session init orchestration. Tier 1 skills in `Skills/system/`.

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

Design phase. No code. Three foundational specs complete. Platform/vertical seam defined. Sessions documented in Notes/.

| Document | Path | Status |
|----------|------|--------|
| ShopFloor Storage Spec v1.0 | `Design Documents/ShopFloor Storage Spec.md` | Updated 2026-04-14 |
| ShopFloor Platform Spec v1.0 | `Design Documents/ShopFloor Platform Spec.md` | Complete 2026-04-14 |
| Skill Designer Spec v1.0 | `Design Documents/Skill Designer Spec.md` | Locked |
| April 9 Office Hours | `Notes/Session-2026-04-09-Office-Hours.md` | Recovered and saved |
| April 14 Design Session | `Notes/Session-2026-04-14-Design-Session.md` | Complete |
| April 14 Roles Design | `Notes/Session-2026-04-14-Roles-Design.md` | Complete |
| April 14 Skill Designer | `Notes/Session-2026-04-14-Skill-Designer.md` | Complete |
| April 14 Platform Spec | `Notes/Session-2026-04-14-Platform-Spec.md` | Pending write |

49 data structure schema templates live in `Data Structures/` (all have `writable_by` and `vertical` in frontmatter as of 2026-04-15).
6 ROLE.md files: 5 StoryEngine vertical roles in `Roles/verticals/storyengine/` + Foreman platform role in `Roles/platform/foreman/`.
10 SKILL.md files: `starting-lineup` (AE, Tier 3), `greenlight-review` (Publisher, Tier 3), `character-creation` (Dev Editor, Tier 3) in `Skills/verticals/storyengine/creative/`; 7 platform skills in `Skills/platform/`: `session-init`, `halt-monitor`, `transaction-manager`, `vertical-registration`, `context-index-generator`, `rebuild` (all Foreman Tier 1) + `skill-designer` (Foreman Tier 3).
3 index files in `.shopfloor/`: `schema-index.json`, `role-index.json`, `skill-registry.json`.
`VERTICAL.md` written 2026-04-15 at repo root.
`StoryEngine Spec.md` written 2026-04-15 in `Design Documents/`.

## What's Next (in order)

1. ~~Update Particle.md~~ ✓ Already correct (particle-as-tag model was reflected)
2. ~~Update Team_Manifest.md~~ ✓ Already correct (five roles already present; system-manifest note added)
3. ~~Update ShopFloor Storage Spec~~ ✓ Complete (dir tree, particle table, open questions, handoff — 2026-04-14)
4. ~~Write five ROLE.md files~~ ✓ Complete (locked 2026-04-14)
5. ~~Create Starting_Lineup.md schema~~ ✓ Complete (v1.1 with JSON schema, reconciled with SKILL.md — 2026-04-14)
6. ~~Generate `schema-index.json` and `role-index.json`~~ ✓ Complete (`.shopfloor/`, 2026-04-14)
7. ~~Write first SKILL.md~~ ✓ Complete (`Skills/creative/starting-lineup/SKILL.md`, 2026-04-14)
8. ~~Write `Skills/creative/skill-designer/SKILL.md`~~ ✓ Complete (Tier 3, Managing Editor, 2026-04-14)
9. ~~Write `System_Manifest.md` schema template~~ ✓ Complete (`Data Structures/Operations/System_Manifest.md`, 2026-04-14)
10. ~~Add `writable_by` field to all schema templates~~ ✓ Complete (49 templates updated 2026-04-14; System_Manifest added to schema-index)
11. ~~Write `Skills/creative/greenlight-review/SKILL.md`~~ ✓ Complete (Publisher, Tier 3, 2026-04-14)
12. ~~Write ShopFloor Platform Spec~~ ✓ Complete (`Design Documents/ShopFloor Platform Spec.md`, 2026-04-14)

13. ~~Write session notes for Platform Spec session~~ ✓ Complete (`Notes/Session-2026-04-14-Platform-Spec.md`)
14. ~~Write `Roles/foreman/ROLE.md`~~ ✓ Complete (`Roles/platform/foreman/ROLE.md`, 2026-04-14)
15. ~~Write `Skills/system/vertical-registration/SKILL.md`~~ ✓ Complete (`Skills/platform/vertical-registration/SKILL.md`, 2026-04-14)
16. ~~Write `VERTICAL.md`~~ ✓ Complete (repo root, 2026-04-15)
17. ~~Restructure `Roles/` and `Skills/` to reflect platform/vertical seam~~ ✓ Complete (2026-04-15). Added `validate-vertical.sh`.
18. ~~Seam violations audit — 5 ROLE.md files~~ ✓ Complete (2026-04-15). Three minor "object model" phrase fixes in AE, Publisher, Proofreader. Developmental Editor and Managing Editor clean.

19. ~~Write StoryEngine Spec~~ ✓ Complete (`Design Documents/StoryEngine Spec.md`, 2026-04-15). All §18.2 vertical concepts: five roles, entity types, particle extensions, particleStatus lifecycle, session state payload, Role_Record activityLog payload, object model record structure.
20. ~~Add `vertical: storyengine` frontmatter to all 49 fiction-domain schema templates~~ ✓ Complete (2026-04-15). 45 files get `vertical: storyengine`; 4 platform Operations files (Scorecard, Role_Record, Team_Manifest, System_Manifest) get `vertical: platform`.
21. ~~Write remaining Foreman Tier 1 SKILL.md files~~ ✓ Complete (2026-04-15). `session-init`, `halt-monitor`, `transaction-manager`, `context-index-generator`, `rebuild` — all in `Skills/platform/`. validate-vertical.sh updated to 27-check. skill-registry.json updated with all 7 platform skills.

22. ~~Design `affinity-generator` platform skill~~ ✓ Complete (`Skills/platform/affinity-generator/SKILL.md`, 2026-04-15). Reclassified to **platform Tier 2** (not Tier 1 — first platform Tier 2 instance). Five affinity types with explicit criteria. QUERY/COMPUTE/smart modes. Staleness model. Cross-skill invocation protocol via `platform_dependencies` in contextFingerprint (requires session-init §7 amendment). v2 product-root scope seeds for cross-vertical use.

**Design phase complete.** All foundational specs, roles, skills, and schemas are written. Up next: implement.

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
- **Governing principle:** "Subject matter expertise is the domain of the vertical. ShopFloor
  knows nothing about fiction. StoryEngine knows nothing about platform internals." Use this
  to resolve any ambiguous placement question.
- **Two tier systems — do not conflate:**
  - Product tiers (0/1/2): what Karen's subscription includes (Stash / Prompt Cookbook / Hyperdrive)
  - Skill architecture tiers (1/2/3): floor management / quality control / production
  - In VERTICAL.md fields: `skill_tier` = skill tier; `product_tier_compatibility` = product tier.
- **Foreman** is a ShopFloor **platform** role (NOT StoryEngine). `Roles/platform/foreman/ROLE.md`.
  Owns: vertical registration, global registry, team manifest, context index generation, halt
  detection, session init, skill design. Tier 1 skills in `Skills/platform/`. Also owns
  `skill-designer` (Tier 3, platform production, Bill-facing only).
- **Managing Editor** is Tier 3 (StoryEngine production). Routes Karen within StoryEngine.
  It is NOT a platform role. Foreman handles platform floor; Managing Editor handles StoryEngine
  creative floor. Do not conflate. Managing Editor does NOT own skill-designer — that is Foreman.
- **VERTICAL.md** is the vertical registration contract. Lives at repo root. Foreman reads and
  validates it on session init. Declares: vertical ID, entity types + prefixes, per-file extensions,
  context indexes, roles, skills.
- **Two registries:**
  - `~/.shopfloor/global-registry.json` — all installed verticals. Foreman writes. Global employee file.
  - `.shopfloor/skills/skill-registry.json` — per-project. Active vertical + evaluation state. Shift roster.
  - `team-manifest.json` retained — per-project shift roster (which roles are active). Distinct from
    global registry. Foreman writes both.
- **platform.halt** — file at product root. Create it to halt all AI execution for the session
  (overrides product tier to 0, no object model writes, audit continues). Delete to restore.
  Replaces "KILLSWITCH" (retired). Creatable on iOS Files app in seconds.
- **Per-file metadata:** platform base fields + vertical extensions. Verticals declare extensions
  in VERTICAL.md under `per_file_extensions`. Platform-reserved fields cannot be overridden.
- **Context indexing** is a generalized platform mechanism. Verticals declare indexes in VERTICAL.md.
  Foreman generates lazily with source-based invalidation. Skills declare needed indexes in
  `contextFingerprint`. The old hardcoded schema-index/role-index are now instances of this mechanism.
- **Entity ID format standardized:** `[PREFIX]-[5-digit-padded-sequence]`, e.g., `CHR-00001`.
  Regex: `^[A-Z]{2,4}-[0-9]{5}$`. Verticals declare type prefixes in VERTICAL.md under `entity_types`
  (2–4 uppercase letters, unique per vertical, platform enforces no cross-vertical conflicts).
- **Particle = tag on a file.** NOT a separate data structure. `isParticle: true` in per-file metadata.
  Platform owns: isParticle, captureMethod, sourceApp, sourceURL, particleStatus (generic lifecycle).
  StoryEngine owns: resonanceNote, linkedStartingLineup, entity chips (declared in VERTICAL.md extensions).
- Capture method enum: `share_sheet / direct / import / sync / manual / promoted` (closed).
  `promoted` = file already existed in Karen's notebooks; she elevated it to particle status.
  Source app = open string auto-populated from Share Sheet metadata. Never hardcode app names.
- The `resonanceNote` field captures Karen's "why" at the moment of particle promotion — distinct
  from later classification notes. Field name is `resonanceNote` in all schemas and specs.
- Skill evaluation has three modes: `warranty` (first N uses, default 10), `active` (prompt
  every N uses, default 3rd), `passive` (observe only). Defaults live in `system-manifest.json`
  under `quality_control`.
- `SKILL_FEEDBACK` events carry a `karensNote` field — free text, optional, most actionable signal.
- The Skill Designer is Bottleneck 19.7 — most context-hungry operation. Mitigated by context
  indexing mechanism (schema-index, role-index as generated instances).
- Object model updates triggered by explicit skill invocation only (Open Question #4 — CLOSED).
- `writable_by` enforcement in Skill Designer: Warning for Bill (can override by fixing schema-index),
  Fail (hard block) for Karen-authored skills. Overrides resolve at schema-index level, not per-skill.
- No forms ever. Conversational UI throughout all three product tiers.

## Directory Structure

```
ShopFloor/
  VERTICAL.md           — StoryEngine registration contract (Foreman reads on session init)
  Design Documents/     — Storage Spec, Platform Spec, Skill Designer Spec, ERD, Seed Data
  Data Structures/      — 49 schema templates (StoryEngine vertical domain)
    Noun Data Structures/   Character, Wound, Scene, Location, Particle, etc.
    Verb Data Structures/   Arc, Chapter, Continuity, Pacing, etc.
    Scaffolding/            Act, Beat, Conformance, Framework, etc.
    Frameworks/             Three-Act, Save the Cat, Seven Point, Story Grid, Hero's Journey
    Operations/             Project, Role_Record, Scorecard, Team_Manifest, System_Manifest
  Assets/               — reference graphics (NotebooksApp study)
  Skills/               — SKILL.md files
    platform/           — ShopFloor platform skills (Foreman owns)
                            vertical-registration (Tier 1), skill-designer (Tier 3)
    verticals/          — vertical-owned skills, grouped by vertical ID
      storyengine/
        creative/       — Tier 3 production: starting-lineup, greenlight-review
        rules/          — Tier 2 quality control (not yet written)
    pending/            — Karen-authored or unreviewed skills awaiting assignment
  Roles/                — ROLE.md files
    platform/           — ShopFloor platform roles
      foreman/          — Foreman: vertical registration, session init, skill design
    verticals/          — vertical roles, grouped by vertical ID
      storyengine/
        acquisitions-editor/
        developmental-editor/
        managing-editor/
        proofreader/
        publisher/
  Notes/                — Session records (written at end of every session)
  App/                  — iOS/macOS Xcode project (Capture.xcodeproj, active Sprint 2+)
  .shopfloor/           — hidden platform infrastructure (not committed; generated at runtime)
    schema-index.json   role-index.json   skill-registry.json
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

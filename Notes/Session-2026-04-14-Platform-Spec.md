# Session — ShopFloor Platform Spec
**Date:** April 14, 2026
**Session type:** Office Hours (architecture) + live spec writing
**Conducted under:** gStack (office-hours)

---

## What We Did

Two-part session.

**Part 1 — Architecture review (office-hours):** The question was whether StoryEngine should be a separate spec that "talks to" ShopFloor, and whether a "Foreman" role would give cleaner vertical separation. Ran adversarial design review, produced approved design doc. Full doc at `~/.gstack/projects/wm-j-ray-ShopFloor/wmjray-main-design-20260414-184308.md`.

**Part 2 — Platform Spec writing:** Walked through every concept in the ShopFloor Storage Spec and assigned each explicitly to PLATFORM or VERTICAL. Written as `Design Documents/ShopFloor Platform Spec.md` (~1,180 lines, 18 sections). Committed as `02b9012`.

---

## The Core Principle (Governing All Future Decisions)

> "Subject matter expertise is the domain of the vertical. ShopFloor knows nothing about fiction. StoryEngine knows nothing about platform internals."

This is the seam. Any ambiguous placement question resolves by asking: does this require fiction domain knowledge? If yes, it's StoryEngine. If it's structural/operational, it's ShopFloor.

---

## Architectural Decisions Locked This Session

### 1. Foreman Role (Platform, Not Vertical)

Added a new role: **Foreman**. ShopFloor platform role, not a StoryEngine role. Lives at `Roles/foreman/ROLE.md`. Tier 1 skills in `Skills/system/`.

Foreman owns:
- Vertical registration (reads and validates `VERTICAL.md` on session init)
- Global registry writes (`~/.shopfloor/global-registry.json`)
- Team manifest writes (`team-manifest.json`)
- Context index generation (lazy, source-based invalidation)
- Halt detection (`platform.halt`)
- Session init orchestration

**Managing Editor is NOT affected.** It stays Tier 3 (StoryEngine production). Managing Editor routes Karen within the fiction vertical. Foreman handles the platform floor. Do not conflate them.

### 2. Two Tier Systems — Never Conflate

Two separate tier systems exist. They share no numbering. Both are "tiers" — that's it.

| System | Values | What It Governs |
|--------|--------|-----------------|
| Product tiers | 0 / 1 / 2 | What Karen's subscription includes (Stash / Prompt Cookbook / Hyperdrive) |
| Skill architecture tiers | 1 / 2 / 3 | Floor management / quality control / production |

In VERTICAL.md: `skill_tier` = skill architecture tier. `product_tier_compatibility` = product tier. The field names encode the distinction.

The SKILL.md-as-universal-contract resolves the product tier question: Tier 0 = Bill reads it, Tier 1 = Claude pre-cooks from it, Tier 2 = Claude executes it. Same file, different engine. Roles are tier-agnostic.

### 3. VERTICAL.md — The Registration Contract

Every vertical declares itself via `VERTICAL.md` at the repo root. Foreman reads and validates it on session init. Failing validation blocks skill execution (Fail-level errors) or warns (Warning-level).

Key VERTICAL.md declarations:
- `vertical_id` — unique identifier (e.g., `storyengine`)
- `entity_types` — type prefixes (2–4 uppercase letters, unique per vertical, platform enforces no cross-vertical conflicts)
- `per_file_extensions` — vertical-specific fields added to the base per-file metadata record
- `context_indexes` — what indexes to generate (Foreman generates lazily)
- `roles` — which ROLE.md files belong to this vertical
- `skills` — skill registry for this vertical

Error taxonomy (7 codes, all Fail-level): `MISSING_REQUIRED_FIELD`, `INVALID_TIER_VALUE`, `DUPLICATE_VERTICAL`, `PATH_NOT_FOUND`, `ENTITY_PREFIX_CONFLICT`, `FIELD_NAME_CONFLICT`, `UNKNOWN_SKILL_TIER`. One Warning: `SCHEMA_PATH_OVERLAP`.

### 4. Two Registry Architecture

Two registries. Different jobs. Do not merge them.

| Registry | Path | What It Is | Who Writes |
|----------|------|------------|------------|
| Global registry | `~/.shopfloor/global-registry.json` | All installed verticals across projects | Foreman |
| Per-project skill registry | `.shopfloor/skills/skill-registry.json` | Active vertical + evaluation state for this project | Foreman |

**team-manifest.json is retained.** It is the shift roster — which roles are active for a given project. Distinct from the global registry (employee file — what's installed system-wide). Foreman writes both. Initial call to retire team-manifest was wrong; user corrected: "The shop foreman knows who shows up for work."

### 5. platform.halt — Replaces KILLSWITCH

`platform.halt` is a file at the product root (inside the project folder, where Karen can see it). Creating it halts all AI execution for the session:
- Overrides product tier to 0
- No object model writes
- Audit trail continues
- Delete the file to restore normal operation

Rationale: creatable on iOS Files app in seconds. No terminal, no tools needed. Karen can pull the rip cord from her phone.

"KILLSWITCH" is retired. The concept lives on as `platform.halt`.

### 6. Per-File Metadata — Base + Extensions

Platform defines a base set of fields in every per-file metadata record. Verticals declare extensions in `VERTICAL.md` under `per_file_extensions`. Platform-reserved fields cannot be overridden.

The split matters for the particle system specifically:

| Owner | Fields |
|-------|--------|
| Platform | `isParticle`, `captureMethod`, `sourceApp`, `sourceURL`, `sourceType`, `particleStatus` (generic states), `lastSurfaced`, `surfaceCount` |
| StoryEngine (via extensions) | `resonanceNote`, `linkedStartingLineup`, entity chips |

`particleStatus` uses generic lifecycle values at the platform level. StoryEngine may map these to fiction-specific names via vertical config — but the underlying state machine is platform-owned.

### 7. Context Indexing — Generalized Platform Mechanism

What were two hardcoded files (`schema-index.json`, `role-index.json`) are now instances of a general platform mechanism.

Verticals declare context indexes in `VERTICAL.md`. Foreman generates them lazily using source-based invalidation (if source files haven't changed, index is current). Skills declare which indexes they need in `contextFingerprint` — the platform loads only what's declared.

The Skill Designer (Bottleneck 19.7) continues to load schema-index and role-index. The difference: those indexes now exist within a generalized mechanism instead of being hardcoded. Other verticals can declare their own indexes using the same machinery.

### 8. Entity ID Format — Standardized

Historical inconsistency (old spec had `CHR-001` in some places, `PRT-00047` in others). Standardized this session.

**Format:** `[PREFIX]-[5-digit-padded-sequence]`
**Examples:** `CHR-00001`, `LOC-00023`, `PRT-00047`
**Regex:** `^[A-Z]{2,4}-[0-9]{5}$`
**Prefix rules:** 2–4 uppercase letters, declared by vertical in `VERTICAL.md` under `entity_types`, unique per vertical, platform enforces no cross-vertical conflicts.

### 9. Session State — Envelope + Payload

Session state has two layers:

- **Envelope** — platform metadata: session ID, vertical ID, role active, tier, timestamps. Platform reads/writes this regardless of vertical.
- **Payload** — vertical-specific context: whatever StoryEngine needs for the active role. Platform passes it through opaquely.

This is the seam in practice: platform knows that a session is running and which role is active. It does not know what that role is doing.

Same split applies to `Role_Record`:
- **Envelope** — platform fields: role ID, vertical, scorecard aggregate, active/inactive state
- **activityLog** — vertical-specific events. Platform appends them; it does not parse them.

### 10. Managing Editor — Stays Tier 3 (StoryEngine)

Question arose: should Managing Editor be reclassified as a platform role?

Decision: no. Managing Editor is a StoryEngine-level role. Coordination within a vertical is production-tier work — it produces direct value for Karen by routing her to the right fiction role. The Foreman handles platform floor management (registrations, halt detection, session init). Managing Editor handles the StoryEngine creative floor.

They are parallel, not redundant. Conflating them would violate the governing principle — Managing Editor has fiction domain knowledge. Foreman has none.

---

## Platform Spec — Section Map

The Platform Spec (`Design Documents/ShopFloor Platform Spec.md`) covers 18 sections:

1. Purpose & Scope
2. Governing Principle
3. The Platform/Vertical Contract (VERTICAL.md schema)
4. Vertical Registration & Validation
5. Global Registry
6. Per-Project Skill Registry
7. team-manifest.json
8. Session Init & Orchestration
9. Skill Execution Model
10. Context Indexing
11. Per-File Metadata
12. The Particle System
13. Entity IDs
14. Object Model Updates
15. Audit Trail
16. platform.halt
17. Skill Evaluation (warranty/active/passive)
18. Platform/Vertical Boundary (authoritative seam table)

§18 is the reference. Two tables: what the platform owns (complete list), what the vertical owns (complete list). Resolve ambiguity by going there first.

---

## Reviewer Loop Note

The spec went through 3 rounds of adversarial review. Scoring regressed across rounds (7→6.5→5) — reviewer getting stricter, not the doc getting worse. At round 3, 5 remaining concerns were resolved concretely rather than deferred. Convergence guard triggered. Convergence at ~9/10.

The lesson: when a reviewer score regresses, don't let it slide. Fix the underlying concern, not the symptom. Deferred issues become debt on every future session.

---

## Delivered This Session (continued after notes were written)

Three additional artifacts completed in the same session:

**`Roles/foreman/ROLE.md`** (new, commit `2965928`)
Platform Foreman role. 4 Tier 1 skills: vertical-registration, session-init, context-index-generator, halt-monitor. Full error taxonomy table. Knows nothing about fiction. Runs before anything else. If it halts, the session ends.

**`Roles/managing-editor/ROLE.md`** (rewritten, commit `2965928`)
Stripped all platform-level responsibilities and skills (session-init, orphan-manager, schema-migrator, backup-restore). Now scoped to StoryEngine creative floor only: routing, scorecard-updater, skill-installer, project-export, skill-designer. Pipeline position updated to show Foreman-first chain.

**`Skills/system/vertical-registration/SKILL.md`** (new, commit `32d22c9`)
Foreman's first Tier 1 skill. 237 lines. Establishes the Tier 1 SKILL.md pattern: execution flow (not conversation flow), `requires_ai: false`, no Karen-facing output. 13-step execution flow. All-or-nothing registry writes on Fail. Documents platform.halt sequencing (halt-monitor fires first in session-init, so this skill never runs in a halted session).

---

## Architectural Amendments (ChatGPT Review Response — same session)

An external review surfaced 4 real architectural gaps. All addressed before moving to VERTICAL.md.

**§19 Source of Truth Hierarchy** (Platform Spec)
4-level hierarchy: file system → per-file metadata → object model records → derived caches.
Derived caches (manifest, registries, indexes) are always rebuildable. Object model records and audit log are irreplaceable. Design constraint: if a structure cannot be rebuilt from levels 1–3, it must not be a derived cache.

**§20 Transaction Model** (Platform Spec)
Pending transaction file written before any multi-step write sequence. Each operation marked completed as it runs. Foreman `transaction-manager` skill recovers incomplete sequences at session init. Idempotency requirements formalized for all 4 write types.

**§21 Rebuild Protocol** (Platform Spec)
Foreman `rebuild` skill reconstructs all 6 derived structures from ground truth. Runs automatically on missing manifest or on Bill's explicit request. Documents what cannot be rebuilt (audit log, global-registry from scratch, Karen's content, object model records themselves).

**Skill I/O Contract** (Skill Designer Spec §3.2 + all 4 SKILL.md files)
Added `inputs` and `outputs` structured fields to YAML frontmatter. Machine-readable mirrors of Section 3 (Context Requirements) and Section 7 (Write-Back Contract). Used by transaction-manager to pre-write pending transaction files. All 4 existing SKILL.md files bumped to v1.1.

Foreman ROLE.md updated with `transaction-manager` and `rebuild` skills + 2 new routing triggers.

What the review got wrong (pushed back on): event system (intentionally deferred), prompt surface area (addressed by context fingerprints), Skill Designer constraints (already have full spec).

Commit: `1f4d52a`

---

## What's Next (from this session)

In order:

1. ~~Write `Notes/Session-2026-04-14-Platform-Spec.md`~~ ✓ this file
2. ~~Write `Roles/foreman/ROLE.md`~~ ✓ Complete (2026-04-14)
3. ~~Write `Skills/system/vertical-registration/SKILL.md`~~ ✓ Complete (2026-04-14)
4. ~~Update `Roles/managing-editor/ROLE.md`~~ ✓ Complete (2026-04-14, platform language stripped)
5. ~~Address architectural gaps from external review~~ ✓ Complete (2026-04-14, §19/§20/§21 + I/O contract)
6. Write `VERTICAL.md` at repo root — StoryEngine's registration declaration (entity type prefixes need deliberate design pass first)
7. Write StoryEngine Spec — all §18.2 vertical concepts from Platform Spec (fiction domain, five roles, entity types, particle extensions)
8. Audit remaining 4 ROLE.md files for seam violations
9. Add `vertical: storyengine` frontmatter to all 49 fiction-domain schema templates

---

## Design Doc Reference

Approved design doc from Part 1 (office-hours):
`~/.gstack/projects/wm-j-ray-ShopFloor/wmjray-main-design-20260414-184308.md`

Supersedes: `wmjray-main-design-20260414-140434.md` (earlier draft, same day)

# Session Notes — VERTICAL.md Design
**Date:** 2026-04-15
**Topic:** Design and write StoryEngine's VERTICAL.md registration contract
**Participants:** Bill Ray, Claude Sonnet 4.6
**Deliverables:** `VERTICAL.md` (repo root), updated `.shopfloor/schema-index.json`

---

## What We Did

Designed and wrote `VERTICAL.md` — the registration contract the Foreman reads at every session init. This is the artifact that formally registers StoryEngine as a ShopFloor vertical: it declares roles, skills, entity types, context indexes, per-file extensions, and product tier compatibility.

Also corrected `schema-index.json` to properly mark Scorecard, Role_Record, Team_Manifest, and System_Manifest as platform entities (not StoryEngine vertical entities).

---

## Decisions Made

### 1. Platform Entity Types Excluded from entity_types

**Decision:** Scorecard, Role_Record, Team_Manifest, and System_Manifest are platform entities and do NOT appear in VERTICAL.md's `entity_types`. The schema-index was updated to reflect this.

**Reasoning:** Platform Spec §4.1 states Scorecard is "platform property; no vertical reads or writes it directly." Platform Spec §6.5 shows Scorecards named `Scorecard_[role-id].json` — a role-id slug, not the `[PREFIX]-[NNNNN]` sequential entity ID system. Declaring `SCD`, `ROL`, `TMF` as entity type prefixes would initialize counters that are never used. The schema-index entries for these were artifacts from before the platform/vertical seam was fully resolved.

**`Project` (PRJ) stays as a vertical entity** — it tracks StoryEngine-specific pipeline state (swain_elements, active_starting_lineup_id, abandonment_history, intent_context) and is writable by vertical roles.

### 2. Particle as Platform Infrastructure — Per-File Extensions Resolved

**Decision:** StoryEngine's `per_file_extensions` contains only the three vertical-owned fields:
- `storyengine_resonanceNote` — Karen's "why" at capture moment
- `storyengine_linkedStartingLineup` — entity ID of linked Starting_Lineup
- `storyengine_captureEntityChips` — array of entity IDs tagged at capture time

**What is NOT declared:** Platform-owned particle fields (`isParticle`, `particleStatus`, `captureMethod`, `sourceApp`, `sourceURL`, `sourceType`, `lastSurfaced`, `surfaceCount`) are platform infrastructure available to all verticals automatically. They must not be re-declared as extensions.

**Reasoning:** Platform Spec §5.2 explicitly assigns those fields to the platform. The §13.2 example VERTICAL.md that included `storyengine_isParticle` and `storyengine_particleStatus` was an inconsistency written before the particle ownership seam was finalized. This session resolved it: the platform owns the particle mechanism; StoryEngine extends it with domain-specific fields.

**Bill's framing confirmed:** Particle = "maybe there's something here, come back to it." That's a platform concept — not fiction-specific. Any vertical benefits from the same capture/curation loop. StoryEngine's `resonanceNote` and entity chips are its domain-specific window into the platform particle system.

### 3. Entity Chips — Single Array

**Decision:** `storyengine_captureEntityChips` is a single array of entity ID strings. Mixed types are fine because entity IDs encode their type in the prefix (e.g., `CHR-00001` is unambiguously a character). No need for three separate arrays.

### 4. product_tier_compatibility — Both Global and Per-Skill

**Decision:** Declared at both levels:
- Global `product_tier_compatibility: [0, 1, 2]` — the vertical as a whole supports all tiers
- Per-skill declarations:
  - `starting-lineup`: `[1, 2]` — useful as prompt template (Tier 1), native execution (Tier 2); no value at Tier 0
  - `greenlight-review`: `[1, 2]` — same reasoning
  - `skill-designer`: `[2]` — most context-intensive skill (Bottleneck 19.7); generates SKILL.md files; no sensible Tier 1 version; Bill-only

### 5. Foreman's Skills Not in VERTICAL.md

**Decision:** `vertical-registration` and other Foreman platform skills are NOT declared in VERTICAL.md's `skills` array. VERTICAL.md is StoryEngine's registration contract. The Foreman reads it; it is not registered by it. The governing principle applies: StoryEngine knows nothing about platform internals.

### 6. Operations/ Included in Schema Paths and Index Sources

**Decision:** `Data Structures/Operations/` is included in both `schema_paths` and `schema-index` sources. Rationale: The Skill Designer needs awareness of all schema templates, including platform entity schemas used in cross-reference validation and the vertical-owned `Project` schema. The platform entity entries (Scorecard, Role_Record, etc.) appear in schema-index for reference only — they carry `platform_entity: true` and `writable_by: platform` markers to distinguish them from vertical-owned types.

---

## New Concept Surfaced — Affinity System (Future Platform Work)

Bill described a cross-vertical content relatedness capability: AI finds connections between pieces of content that are not explicitly linked in the object model. Different from explicit object model links (chapter → scenes); different from particle resurfacing (spaced repetition of individual particles).

**Key design decisions made in this session:**

| Question | Decision |
|----------|----------|
| Where does relatedness live? | Platform-level `affinity-index` in `.shopfloor/` — regeneratable, lazy, same pattern as schema-index and role-index |
| What triggers discovery? | On-demand, when a role fires it. NOT at particle promotion (promotion happens at Tier 0 where there's no AI; also sluggish if triggered on every promotion). |
| Does this affect VERTICAL.md today? | No. Particles are platform entities; affinity between particles is platform infrastructure. StoryEngine benefits automatically without needing to declare anything. |

**Future platform work required:**
- Design `affinity-generator` — a new Foreman Tier 1 skill that computes semantic/thematic connections between particles on demand
- Define affinity-index format (accumulates discovered relationships over time; feeds back into resurfacing)
- Define role invocation API: how a vertical role (e.g., Managing Editor) requests affinity computation from the platform
- Consider affinity scope: per-particle ("what relates to this?") vs. global precomputation

This capability crosses vertical boundaries — a Readwise-synced highlight and a StoryEngine particle can both be particles (platform entities) and can be connected by the affinity system without either vertical needing to know about the other.

---

## schema-index.json Corrections

Four entries updated to reflect platform entity status:

| Type | Old id_format | New id_format | Old writable_by | New writable_by |
|------|--------------|---------------|-----------------|-----------------|
| Scorecard | SCD-NNN | Scorecard_[role-id] | managing_editor | platform |
| Role_Record | ROL-NNN | Role_Record_[role-id] | managing_editor | platform |
| Team_Manifest | TMF-001 | singleton | managing_editor | platform |
| System_Manifest | singleton | singleton | managing_editor | platform |

Each entry also received `platform_entity: true` and an explanatory `note` field.

---

## What's Next (Updated Order)

The CLAUDE.md "What's Next" list is now updated through item 16.

**Up next:**
17. Write StoryEngine Spec — all §18.2 vertical concepts from Platform Spec (fiction domain, five roles, entity types, particle extensions)
18. Update existing 5 ROLE.md files — remove platform language from Managing Editor; audit others for seam violations
19. Add `vertical: storyengine` frontmatter to all 49 fiction-domain schema templates

**Also queued (from this session):**
- Design affinity-generator platform skill (new Foreman Tier 1 skill)
- Write `Notes/` entry capturing the affinity system design decisions above

---

## Files Changed This Session

| File | Action | Notes |
|------|--------|-------|
| `VERTICAL.md` | Created | StoryEngine registration contract |
| `.shopfloor/schema-index.json` | Updated | Platform entity entries corrected |

---

# Session Continuation — Directory Restructure + Seam Audit
**Date:** 2026-04-15 (same session, continued)
**Topic:** Roles/Skills directory restructure; skill-designer platform migration; seam violation audit

---

## What We Did

Recognized the `Roles/` and `Skills/` flat directory structure didn't reflect the platform/vertical seam. Restructured both trees to make the seam visible in the filesystem, moved skill-designer from Managing Editor to Foreman, created a Tier 0 validation test, and audited all 5 StoryEngine ROLE.md files for seam violations.

---

## Decisions Made

### 7. Roles Directory Restructured to Reflect Platform/Vertical Seam

**Decision:** Reorganized `Roles/` into:
```
Roles/
  platform/
    foreman/ROLE.md
  verticals/
    storyengine/
      acquisitions-editor/ROLE.md
      publisher/ROLE.md
      developmental-editor/ROLE.md
      proofreader/ROLE.md
      managing-editor/ROLE.md
```

**Reasoning:** With only one Foreman and five StoryEngine roles today, a flat `Roles/` directory reads like a hairball. The platform/vertical split is the most important architectural boundary in the system — it should be visible in the filesystem. Future verticals (e.g., storyengine-v2, a music vertical) slot under `Roles/verticals/[vertical-id]/` without disturbing the platform structure.

### 8. Skills Directory Restructured to Match

**Decision:** Reorganized `Skills/` into:
```
Skills/
  platform/
    vertical-registration/SKILL.md
    skill-designer/SKILL.md
  verticals/
    storyengine/
      creative/
        starting-lineup/SKILL.md
        greenlight-review/SKILL.md
  pending/
    (Karen-authored skills awaiting review)
```

**Reasoning:** Same governing principle — directory structure should make the platform/vertical boundary visible. The old `Skills/system/`, `Skills/rules/`, `Skills/creative/` taxonomy organized by tier, but tier is an implementation detail. Platform vs. vertical is the primary architectural distinction.

### 9. skill-designer Moved to Foreman (Platform)

**Decision:** `skill-designer` SKILL.md moved from `Skills/creative/` (Managing Editor, StoryEngine vertical) to `Skills/platform/` (Foreman, platform). ROLE.md updated: `role: managing-editor` → `role: foreman`. Foreman ROLE.md updated to include skill-designer in Skills and Responsibilities.

**Reasoning:** The skill-designer generates SKILL.md files for any role — StoryEngine roles, future vertical roles, platform roles. A skill that crosses vertical boundaries cannot be owned by a vertical role. Bill invokes it explicitly; it's not part of StoryEngine's creative pipeline. The platform/vertical governing principle resolves this unambiguously.

**skill-designer stays Tier 3:** It needs the 12K token context budget (Bottleneck 19.7 — most context-hungry operation in the system). Tier classification is about work type and token budget, not ownership layer. Foreman can own Tier 3 skills.

**product_tier_compatibility: [2] only** — skill design requires native AI execution. No sensible Tier 1 (Prompt Cookbook) version exists. Bill-only invocation.

### 10. Tier 0 Test — validate-vertical.sh

**Decision:** Created `validate-vertical.sh` at repo root. Manually validates all paths declared in VERTICAL.md — same PATH_NOT_FOUND checks the Foreman's `vertical-registration` skill would do at runtime.

**Why a shell script:** The insight arose from the question "couldn't I design a skill that validates the vertical?" The answer is: yes, but a skill is overkill for Tier 0. A shell script runs before any AI context is loaded, has no dependencies, and exits 0 on pass / 1 on failure. It's the CI safety net, not the runtime tool.

**22-check structure:** role paths (5), skill paths (2), schema paths (5), index source paths (6), platform skill/role paths (3) + contract file (1). All 22 passed on first run after directory restructure.

### 11. Seam Violation Audit — Item 18

Audited all 5 StoryEngine ROLE.md files for language that crosses the platform/vertical seam. Three violations found and fixed:

| File | Violation | Fix |
|------|-----------|-----|
| `acquisitions-editor/ROLE.md` | "Maintain the Starting_Lineup record **in the object model**" | Removed "in the object model" — the vertical doesn't address platform internals |
| `publisher/ROLE.md` | "**Starting_Lineup object model record**" | Removed "object model" — same principle |
| `proofreader/ROLE.md` | "inconsistencies between the manuscript and **object model** records" | "object model records" → "entity records" — StoryEngine knows about entities, not the object model |

**Developmental Editor:** Clean. No seam violations.

**Managing Editor:** Updated separately — removed skill-designer from Skills/Responsibilities (it moved to Foreman); updated pending/ path; updated routing trigger to reflect ME passes signals to Foreman's skill-designer rather than designing skills itself.

---

## Updated .shopfloor Index Files

Both `.shopfloor/role-index.json` and `.shopfloor/skill-registry.json` updated to reflect:
- New file paths under `platform/` and `verticals/storyengine/` layouts
- Foreman entry added to role-index (was missing)
- skill-registry restructured into `platform_skills` and `vertical_skills` sections
- managing_editor tier corrected: 1 → 3 (was a pre-existing error)
- skill-designer removed from managing_editor entry; added to foreman entry

---

## Files Changed This Session (Continuation)

| File | Action | Notes |
|------|--------|-------|
| `Roles/platform/foreman/ROLE.md` | Moved + Modified | Added skill-designer (Tier 3) to Skills and Responsibilities |
| `Roles/verticals/storyengine/acquisitions-editor/ROLE.md` | Moved + Modified | Seam fix: removed "in the object model" |
| `Roles/verticals/storyengine/publisher/ROLE.md` | Moved + Modified | Seam fix: removed "object model" |
| `Roles/verticals/storyengine/proofreader/ROLE.md` | Moved + Modified | Seam fix: "object model records" → "entity records" |
| `Roles/verticals/storyengine/developmental-editor/ROLE.md` | Moved | No seam violations |
| `Roles/verticals/storyengine/managing-editor/ROLE.md` | Moved + Modified | Removed skill-designer; updated pending/ path; updated routing trigger |
| `Skills/platform/vertical-registration/SKILL.md` | Moved | No content changes |
| `Skills/platform/skill-designer/SKILL.md` | Moved + Modified | role: foreman; date_modified updated |
| `Skills/verticals/storyengine/creative/starting-lineup/SKILL.md` | Moved | No content changes |
| `Skills/verticals/storyengine/creative/greenlight-review/SKILL.md` | Moved | No content changes |
| `.shopfloor/role-index.json` | Updated | Foreman added; paths corrected; tier/skill fixes |
| `.shopfloor/skill-registry.json` | Updated | Restructured platform_skills/vertical_skills; paths corrected |
| `validate-vertical.sh` | Created | 22-check Tier 0 path validation script |
| `CLAUDE.md` | Updated | Directory structure, current status, key decisions, What's Next |

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

---
skill_id: affinity-generator
skill_name: Affinity Generator
version: "2.0"
tier: 2
role: foreman
deployment_targets:
  - mobile
  - desktop
requires_ai: true
product_tier_compatibility: [2]
status: draft
date_created: "2026-04-15"
date_modified: "2026-04-15"
authored_by: bill
inputs:
  - resource: per-file-metadata
    scope: all
    required: true
  - resource: particle-content
    scope: skill-specific
    required: true
  - resource: affinity-index
    scope: system
    required: false
  - resource: session-state
    scope: system
    required: true
outputs:
  - resource: affinity-index
    action: create-or-update
  - resource: audit
    action: append
---

<!-- Version history
  1.0 (2026-04-15) — Initial draft. Bill Ray + Claude Sonnet 4.6. Incomplete: invocation
                     protocol undefined, affinity taxonomy vague, no staleness model, no
                     query mode, tier assignment unresolved.
  2.0 (2026-04-15) — Complete rewrite. Bill Ray + Claude Sonnet 4.6.
                     Resolves: tier reclassified to Tier 2 (platform analysis, not floor management);
                     cross-skill invocation protocol defined; five-type affinity taxonomy with
                     explicit criteria; QUERY vs COMPUTE modes; staleness model; platform_dependencies
                     mechanism for vertical skill station assembly.
                     Design seeds: Notes/Session-2026-04-15-VERTICAL.md.
                     Platform Spec references: §5 (Particle), §8 (Context Indexing), §12 (Skill Tiers).
-->

---

## 1. Identity

Affinity Generator finds connections between particles that are not explicitly linked in the object model. Given one or more target particles, it reads their content, resonance notes, and entity chips, then evaluates other particles in the project against five affinity types — thematic, tonal, character, imagistic, and structural. Results accumulate in `.shopfloor/affinity-index.json`. The skill operates in two modes: QUERY (return what is already known) and COMPUTE (find new connections using AI). The invoking vertical role decides which mode to use and what to surface to Karen.

**Belongs to:** Foreman (platform Tier 2)
**When it runs:** On-demand, mid-session, when a vertical role invokes it via the cross-skill invocation protocol. Never automatic at session start. Never triggered by particle promotion.
**Karen's experience:** Indirect. A vertical role surfaces specific connections in its own voice. Karen may see: "Something you captured last March is directly relevant to your protagonist's wound — want me to show you?"

---

## 2. Purpose

Karen captures material across months and years. A sensory image. A dream fragment. A line overheard in a coffee shop. These don't know about each other. They sit in separate notebooks, unlinked, unrelated in the object model. Many of them connect — thematically, emotionally, structurally — in ways Karen hasn't consciously articulated.

The affinity-generator surfaces those connections in the moment Karen needs them. Not as a list to browse — as a specific answer to a specific question the active role is already inside with Karen. When the Acquisitions Editor is trying to surface a protagonist's wound, the affinity-generator finds the particle from nine months ago that is exactly the wound. The system remembered something Karen had already written.

This is not keyword search or tag matching. It is multi-dimensional analysis: what does this material *mean*, what territory does it inhabit, what does it feel like, who does it behave like?

---

## 3. Tier Classification

**This skill is platform Tier 2, not Tier 1.** The Platform Spec §12 describes Tier 2 as "quality control" owned by "platform rules roles (v1.0: TBD)." The affinity-generator is the first instance of a platform-owned Tier 2 skill — analysis work (not floor management) that crosses vertical boundaries.

**Why not Tier 1:** Tier 1 is mechanical floor management — it runs without AI and is invisible to Karen. This skill requires Claude execution and produces Karen-adjacent value. Putting it at Tier 1 would mean either lying about `requires_ai` or exceeding the 8K context budget on any project with significant particle counts.

**Why not Tier 3:** Tier 3 is production work owned by vertical roles and directly triggered by Karen's conversation. This skill is invoked by a vertical role, not by Karen, and it has no domain knowledge about fiction, legal arguments, or any other vertical topic. It computes relationships between pieces of text. That is platform infrastructure.

**Practical implication:** This skill uses the Tier 2 context budget of 10K tokens. The Foreman's Tier 1 session-init sequence does not include it — it runs on-demand via the cross-skill invocation protocol (§5).

---

## 4. Context Requirements

| Resource | Scope | Required | Notes |
|----------|-------|----------|-------|
| Per-file metadata (`files/[UUID].json`) | all | yes | Read to identify all particles; provides resonanceNote and captureEntityChips |
| Target particle content | skill-specific | yes | The actual file Karen wrote — read at invocation time |
| Candidate particle content | all | yes | Read up to context budget; priority order defined in §6 |
| Existing affinity-index | system | no | Read first in QUERY mode; read to skip known pairs in COMPUTE mode |
| `session-state.json` | system | yes | Provides active vertical context; used to scope affinity types to what the invoking role needs |

**Context budget:** 10K tokens (Tier 2). Budget is split approximately:
- ~500 tokens: per-file metadata scan (resonanceNote + captureEntityChips only)
- ~2K tokens: target particle(s) full content
- ~6K tokens: candidate particles (full content up to budget; resonanceNote-only fallback)
- ~1.5K tokens: skill instructions + affinity-index read

**Budget strategy:** If candidate count × average content size would exceed the 6K candidate budget, priority-sort candidates before reading (§6, step 4). Read highest-priority candidates in full; fall back to resonanceNote-only for the rest. Never abort — always return what was found within budget.

---

## 5. Cross-Skill Invocation Protocol

This is a platform Tier 2 skill invoked mid-session by a vertical Tier 3 skill. The mechanism is **platform_dependencies** — a vertical skill declares its dependency in its `contextFingerprint`, and session-init loads this skill's SKILL.md into the station as part of the vertical role's context assembly.

**Vertical skill declares the dependency:**
```yaml
contextFingerprint:
  objectModel: [...]
  system: [...]
  platform_dependencies:
    - skill: affinity-generator
      modes: [query, compute]
```

**Session-init loads the SKILL.md** at station assembly time (step 7 of session-init). The station now contains both the vertical skill's context and the affinity-generator instructions.

**Invocation syntax (in a vertical skill's instruction set):**

```
INVOKE platform:affinity-generator {
  "mode": "query",           # or "compute" or "smart"
  "target_uuids": ["uuid-1", "uuid-2"],
  "affinity_types": ["thematic", "character"],   # optional filter; omit for all five types
  "max_results": 5,           # optional; default 10
  "min_score": 0.5            # optional; overrides system-manifest default
}
```

**Result is returned inline** — the platform skill executes and passes its structured result back to the invoking vertical skill's execution context. The vertical skill continues from that point using the result as it sees fit.

**Invocation modes:**
- `query` — Return affinities already in the index for the target particles. No new AI computation. Fast. Use when context budget is tight or Karen needs a quick answer.
- `compute` — Run full affinity computation against all candidate particles not already scored. Updates the index. Slower. Use when a new particle was just promoted or the index is thin.
- `smart` — Default. Query first; if results below `min_score` threshold or fewer than `max_results/2` found, proceed with compute for unscored pairs. Best balance.

---

## 6. Five Affinity Types

Every affinity entry carries a type. Types are not mutually exclusive — a strong affinity may register on multiple dimensions. Each type has explicit evaluation criteria so Claude scores consistently.

### Type 1: Thematic
Both particles argue the same question or inhabit the same thematic territory. The territory may be named or unnamed, but a thoughtful reader would say "these are about the same thing at a deeper level."

**Criteria:** Do both particles circle a common value tension (loyalty vs. self-preservation; ambition vs. belonging)? Do they both implicitly ask the same question about human experience? Naming the shared question is required — "both about loneliness" is insufficient. "Both asking whether disappearing from someone's life counts as abandonment" is specific enough.

**Score weight:** Highest — thematic kinship is the most productive kind for a fiction author.

### Type 2: Tonal
Both particles carry the same emotional atmosphere or register, regardless of surface subject matter. Not the same emotion — the same *texture* of feeling.

**Criteria:** If you set both particles to the same film score cue, would it fit both? Do both invoke a similar quality of attention in the reader — slow and heavy, bright and exposed, cold and peripheral? The tonal description should name a specific register, not a label. "Melancholy" is a label. "The specific quiet of a house after someone has left it" is a register.

**Score weight:** Medium — tonal affinity is useful for voice-building and scene placement; less productive for premise development.

### Type 3: Character / Wound
The particles suggest similar character dynamics, psychological patterns, or wound signatures. This may be the same character encountered at different times, two distinct characters with parallel psychology, or a particle that illuminates the interior life of a character in another particle.

**Criteria:** Do both particles contain a figure (real or imagined) who behaves from the same false belief? Do they show the same failure mode — the way a person shrinks, overreaches, deflects, or holds on? Entity chips provide a signal here: shared character or wound chips are strong evidence. But a character can appear without being named.

**Score weight:** High for Acquisitions Editor and Developmental Editor invocations; lower for Proofreader.

### Type 4: Imagistic
The particles share a recurring image, sensory pattern, or symbolic vehicle. The image need not be identical — it may be a family of images (water, thresholds, enclosure, hands, light through windows).

**Criteria:** Would the same visual artist find both particles useful as reference? Is there a concrete, sensory element that recurs? The image must be specific enough to be tracked. "Both involve weather" is too broad. "Both use rain as a measure of how much isn't being said" is specific enough.

**Score weight:** Medium — imagistic affinity is generative for prose development but less structural than thematic or character affinity.

### Type 5: Structural
Both particles have the same narrative function potential. They could both serve as inciting incidents, both could anchor a dark night, both could function as the moment the protagonist receives a wound. This is the most speculative type — it requires reading intent, not just content.

**Criteria:** Does the particle describe a rupture, a discovery, a moment of refusal, or another structurally legible event? Does the same Swain element map onto both? Use this type sparingly — only when structural function is unambiguous, not merely possible.

**Score weight:** Medium for Acquisitions Editor; highest for Developmental Editor.

---

## 7. Affinity Index Format

```json
{
  "indexId": "affinity-index",
  "vertical": "storyengine",
  "schemaVersion": "1.0",
  "lastUpdated": "2026-04-15T14:32:00Z",
  "entryCount": 12,
  "defaultThreshold": 0.4,
  "entries": [
    {
      "pairId": "uuid-a:uuid-b",
      "particle_a": "3F8C2A1D-0000-0000-0000-000000000001",
      "particle_b": "A7E94C22-0000-0000-0000-000000000002",
      "affinities": [
        {
          "type": "character",
          "score": 0.87,
          "description": "Both figures operate from a false belief that staying silent is the same as keeping peace — and both pay the same price for it",
          "evidence": ["resonanceNote of particle_a", "wound chip WND-00003 on particle_b"]
        },
        {
          "type": "thematic",
          "score": 0.74,
          "description": "Both ask whether a person can love someone they've never allowed to know them",
          "evidence": ["particle_a content paragraph 2", "particle_b full content"]
        }
      ],
      "maxScore": 0.87,
      "computedAt": "2026-04-15T14:32:00Z",
      "sourceModifiedAt": {
        "particle_a": "2026-04-14T09:00:00Z",
        "particle_b": "2026-03-22T16:45:00Z"
      },
      "session_id": "SES-0042",
      "computedBy": "managing-editor"
    }
  ]
}
```

**Key design decisions in the format:**

`pairId` — canonical pair key: lower UUID alphabetically, colon, higher UUID. Ensures each pair has exactly one entry regardless of which was "target" and which was "candidate."

`affinities` — array of typed affinity objects. A pair may have multiple affinity types. The invoking role filters by type based on what Karen needs in this conversation.

`maxScore` — highest score across all affinity types for this pair. Used for sorting results when the invoking role asks for "top N affinities" without filtering by type.

`sourceModifiedAt` — the `dateModified` of each particle at the time of computation. Used for **staleness detection**: if either particle's current `dateModified` in its per-file record is newer than this, the entry is stale and should be recomputed.

`computedBy` — which vertical role triggered the computation. Useful for warranty analysis (does the Developmental Editor's affinities differ in quality from the Managing Editor's?).

---

## 8. Execution Flow

```
1. PARSE INVOCATION
   Read: mode (query | compute | smart), target_uuids, affinity_types (optional filter),
         max_results, min_score (fallback to system-manifest.json quality_control.affinity_threshold).

2. LOAD AFFINITY INDEX
   Read .shopfloor/affinity-index.json.
   If absent: initialize empty structure (see §7). Proceed as compute mode (index is empty).

3. STALENESS SWEEP (always run, even in query mode)
   For each entry in the index whose particle UUIDs match any target UUID:
     Read current dateModified for each particle from files/[UUID].json.
     If current dateModified > entry.sourceModifiedAt for either particle: mark entry STALE.
   Stale entries are not returned in query results. They are flagged for recomputation.

4. QUERY MODE (or SMART — query phase)
   Collect all non-stale entries where particle_a or particle_b is in target_uuids.
   Filter by affinity_types if provided.
   Filter by min_score.
   Sort by maxScore descending. Truncate to max_results.
   If mode = "query": go to step 8 (WRITE and RETURN).
   If mode = "smart": if results count >= max_results / 2 AND max result score >= min_score + 0.1:
     go to step 8 (sufficient results found). Otherwise: continue to COMPUTE phase.

5. IDENTIFY COMPUTE CANDIDATES (compute mode or smart fallback)
   From all files/[UUID].json records: collect UUIDs where isParticle: true.
   Exclude:
     - Target UUIDs themselves.
     - Pairs already indexed (non-stale entries) at max_score >= min_score.
     - Stale entries are NOT excluded — they will be recomputed.
   Priority-sort candidates for context budget allocation:
     Priority 1: particles with shared captureEntityChips with any target particle
     Priority 2: particles with non-empty resonanceNote
     Priority 3: remaining particles (resonanceNote-only read if budget exhausted)

6. LOAD PARTICLES
   Load target particles: full content + resonanceNote + captureEntityChips for each.
   Load candidates in priority order:
     Allocate ~6K tokens to candidate content.
     For each candidate: attempt full content read. If budget would be exceeded:
       fall back to resonanceNote + captureEntityChips only.
     Track which candidates were read fully vs. resonanceNote-only.

7. COMPUTE AFFINITIES
   For each (target, candidate) pair in the compute set:
     Evaluate all five affinity types (or filter if affinity_types specified in invocation).
     For each type: produce a score 0.0–1.0 and a description meeting the type's criteria (§6).
     The description must be specific — not a label but a characterization.
     The evidence field names the source material used: "resonanceNote of particle_a",
     "captureEntityChips overlap (CHR-00001)", "particle_b content paragraph 3", etc.
     Only record an affinity type if score >= min_score.
     A pair with no type scoring above min_score is still recorded as a NULL_AFFINITY entry
     (prevents recomputation on future smart-mode passes):
       { "pairId": "...", "affinities": [], "maxScore": 0.0, "computedAt": "...", ... }

8. WRITE AFFINITY INDEX
   Remove stale entries for target pairs (replacing them with recomputed entries).
   Add all new entries (affinities and null-affinities) to the index.
   Update lastUpdated and entryCount.
   Write .shopfloor/affinity-index.json.

9. LOG
   Append AFFINITY_COMPUTED to audit.jsonl:
     { "event": "AFFINITY_COMPUTED", "timestamp": "...", "session_id": "...",
       "mode": "[mode]", "target_count": N, "candidates_evaluated": M,
       "new_affinities": K, "stale_recomputed": J, "null_pairs": L,
       "invoking_role": "[role_id]", "context_budget_hit": true|false }

10. RETURN TO INVOKING ROLE
    {
      "mode_executed": "compute | query | smart:compute | smart:query",
      "affinities": [
        {
          "particle_a": "[UUID]", "particle_b": "[UUID]",
          "type": "[type]", "score": 0.87,
          "description": "...", "evidence": [...]
        },
        ...
      ],
      "total_pairs_in_index": N,
      "candidates_not_loaded": K,     # resonanceNote-only due to budget
      "context_budget_hit": false
    }
    Results are sorted by score descending and truncated to max_results.
    Each result is a single (pair × type) — a pair with two affinity types appears twice.
    The invoking role decides which results to surface to Karen, in what order, and in what language.
```

---

## 9. Output Format

**Returned to invoking role (not emitted to Bill or Karen):**
```json
{
  "mode_executed": "smart:compute",
  "affinities": [
    {
      "particle_a": "3F8C2A1D-...",
      "particle_b": "A7E94C22-...",
      "type": "character",
      "score": 0.87,
      "description": "Both figures operate from a false belief that staying silent is the same as keeping peace — and both pay the same price for it",
      "evidence": ["resonanceNote of particle_a", "wound chip WND-00003 on particle_b"]
    },
    {
      "particle_a": "3F8C2A1D-...",
      "particle_b": "C1B34F7E-...",
      "type": "thematic",
      "score": 0.74,
      "description": "Both ask whether a person can love someone they've never allowed to know them",
      "evidence": ["particle_a content paragraph 2", "particle_b full content"]
    }
  ],
  "total_pairs_in_index": 31,
  "candidates_not_loaded": 2,
  "context_budget_hit": false
}
```

**Audit entry:**
```
AFFINITY_COMPUTED — mode: smart:compute, 1 target, 14 candidates, 3 new affinities, 0 stale recomputed
```

---

## 10. Object Model Writes

| Write | Target | Condition |
|-------|--------|-----------|
| New and recomputed affinity entries | `.shopfloor/affinity-index.json` | Compute or smart:compute mode |
| Null-affinity entries | `.shopfloor/affinity-index.json` | Pairs evaluated and scored below threshold |
| `AFFINITY_COMPUTED` event | `audit.jsonl` | Every invocation |

**Affinity-index is not part of the write-back transaction contract** (Platform Spec §3.3) because:
1. Entries are UUID-keyed, not entity-ID-keyed — not tracked in objectModelRegistry
2. Entries are recomputable from source — derived, not authoritative
3. A partial write (some entries written, interrupted before completion) is safe — the next invocation recomputes the missing pairs

A failed write to affinity-index.json is logged as a warning. The skill returns its results to the invoking role regardless of whether the write succeeded.

---

## 11. Quality Control

**Evaluation mode:** Warranty (first 10 invocations), then active every 3rd invocation. This skill produces the most subjective output in the platform — quality needs sustained monitoring.

**What Bill watches for during warranty:**

*Score calibration:*
- Are 0.87 scores actually the best affinities? Or are the 0.5 scores surprising Karen?
- Is 0.4 the right threshold? Should null-affinity entries be recorded at a higher cutoff?

*Type accuracy:*
- Are "thematic" scores actually thematic? Or is the model collapsing everything into character?
- Is the "structural" type generating false positives (any rupture labeled as "inciting incident potential")?

*Description quality:*
- Are descriptions specific or generic? "Both involve loss" = generic and not useful. "Both ask whether grief is something you survive or something you become" = specific and generative.
- Is the evidence field accurate? Does it cite the actual source material that drove the score?

*Smart mode behavior:*
- Is "smart" correctly deciding when to compute vs. return query results?
- Does the `max_results / 2` threshold need adjustment?

**karensNote is the highest-value signal.** When Karen says "I never would have connected those two" (positive) or "I don't see how those are related" (negative), Bill records this against the specific pair and type in the warranty notes. Five strong negatives on "imagistic" affinities = lower the imagistic weight or tighten its criteria.

---

## 12. Notes

**Tier 2 at platform layer — a new instance.** The Platform Spec §12 describes Tier 2 as owned by "platform rules roles (v1.0: TBD)." This skill is the first concrete example: the Foreman owns a Tier 2 skill because it is analysis work (not floor management) that crosses vertical boundaries. If more platform Tier 2 skills emerge, they follow this pattern. Update Platform Spec §12 to note: "Foreman may own Tier 2 skills where the analysis is cross-vertical and domain-agnostic."

**platform_dependencies — a new contextFingerprint field.** The `platform_dependencies` field in a vertical skill's `contextFingerprint` is introduced by this skill. Session-init's station-assembly step (step 7) needs to be updated to read and load declared platform dependencies. This is a Platform Spec §3.2 and session-init SKILL.md amendment.

**NULL_AFFINITY entries serve a purpose.** Recording pairs that scored below threshold prevents the compute phase from evaluating the same pair on every smart-mode invocation. As Karen's particle collection grows, null-affinity entries become the majority — without them, every smart-mode invocation re-evaluates the entire corpus. The `computedAt` timestamp on null entries enables recomputation if either particle's content changes.

**Scope in v1.0: project-level.** The affinity-index lives at `.shopfloor/affinity-index.json` inside the active project's `.shopfloor/` directory. Particles from other projects are not evaluated.

**Scope in v2+: product root.** When the platform supports multiple projects and multiple verticals, the affinity-index should migrate to the product root (e.g., `StoryEngine/affinity-index.json`, a sibling to `.shopfloor/`). A Readwise-synced highlight and a StoryEngine particle are both particles — the platform concept of `isParticle: true` crosses vertical boundaries. The affinity-generator's analysis criteria are already vertical-agnostic (no fiction-specific vocabulary in the five types). The migration requires: (1) updating the index's scope field, (2) updating session-init's station-assembly to load the product-root index rather than the project-level one, (3) updating the `pairId` format to include project UUIDs for disambiguation. This should not require changes to the skill's execution logic.

**Why NOT at session-init.** Affinity computation requires AI and significant context — running it on every session start would make the Foreman a bottleneck that degrades Karen's session-start experience. It runs when a vertical role needs it and not before. This is the right trade-off: a slightly slower response the first time Karen asks "what else connects to this?" versus a slower session start every time.

**"Smart mode" is the production default.** In a mature skill, smart mode should dominate. It respects Karen's time (query-first is fast) while keeping the index fresh (compute-fallback fills gaps). During warranty, Bill should evaluate whether the smart-mode decision threshold (`max_results / 2`) is well-calibrated or needs adjustment for Karen's specific particle collection.

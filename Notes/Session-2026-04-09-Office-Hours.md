# Office Hours Session — Product Viability Analysis
**Date:** April 9, 2026  
**Session type:** Product viability analysis + architecture design + implementation planning  
**Source:** Recovered from Claude Code session `1405c8a5-047a-4677-912c-a53dc3a67398`  
**Original location:** `~/Desktop/WriteTrack/WriteTrack`

---

## Phase 1: Product Discovery

### Bill's Initial Pitch
A "workbench for fiction writers" — specifically plotters (not pantsers). Core idea: fast capture of ideas (particles), resurfacing them via AI, alongside story structure tools (character arcs, continuity, plot hole detection). Positioned alongside Scrivener and Aeon Timeline, not replacing them.

### The Core Pain — "Particle Rot"
The thing Bill actually loses: the line overheard at the supermarket, the film scene, the passage from a book — captured somewhere and never seen again.

Bill's 20-year, 3-layer manual system:
- Apple Calendar as the foundation
- Diarium as the narrative layer
- Scrivener/Aeon as the harvest layer
- All connected with manual URL scheme tendons

**Memorable quotes:**
- "Chainsaw technology when what is needed is a butter knife."
- "Tell me the same story, only different." (Nicholas Ray)
- "Planting seeds in Calendar, gardening in Diarium, harvesting in Aeon and Scrivener."

### Second Opinion (Independent AI Subagent)
Confirmed: "The founder has already designed the product — they just haven't built it." The four-stage metaphor is the data model.

---

## Final Premises (Locked)

1. Core pain = AI retrieval and resurfacing of collected particles at the moment of creative need
2. iPhone primary, desktop secondary — inspiration happens away from a desk
3. Sits alongside existing tools — integration hooks, not migration
4. Structure (character profiles, 3-act awareness) is the front door in v1; particle resurfacing is the kitchen where people actually live
5. The movie/literary inspiration engine ("Tell me the same story, only different") is the moat and differentiator — plan for it architecturally, ship in v1.5

**Platform inversion decision:** Instead of WriteTrack connecting to Scrivener, Scrivener should eventually connect to WriteTrack via API. The particle engine becomes infrastructure other tools hook into.

---

## Phase 2: Proof of Concept Experiments

### Film Experiment
Same prompt about a reunion scene involving Rob Berkley. AI returned scene selections from *Damage* (1992), *The Ice Storm*, *Beautiful Girls*, *Ordinary People*, *Breaking Bad*. Organized by narrative function with "For Rob's scene" annotations — scene construction advice, not film trivia.

**Finding:** YouTube link problem identified — copyright enforcement makes direct links volatile; search queries are the fallback.

### Diarium Experiment
Against 5,813 diary entries spanning 22+ years. Two-pass retrieval, under 2 minutes. AI organized results thematically:
- "THE WEIGHT ROB CARRIES"
- "THE REUNION MECHANICS"
- "THE GHOST LOGIC"

**Key discovery:** The Updike Leila piece from December 2023 was surfaced — the physical choreography of a man's heart thumping as he approached a woman, almost a draft of the reunion scene. Bill had forgotten it existed.

**Technical finding:** Diarium's live data is a SQLite database at `~/Library/Containers/mac.partl.Diarium/Data/data.db`. Bill already had 328 entries tagged "Particle" and 50 tagged "WriteTrack" inside Diarium — had been building the data model for years inside another app without realizing it.

**Assessment: "Both experiments work. The thesis is proven."**

---

## Phase 3: Architecture Decisions

### Iceberg Architecture
Coined during this session. Karen sees only "books and pages." Everything below the waterline — skills, object model, AI layer — is invisible to her.

### Time as Default Taxonomy
Rather than requiring users to tag or file, the capture timestamp is automatic structure. "You don't have to create folders. The date you captured the particle is part of its metadata."

### Capture Model
Two-layer capture inspired by Stash and Readwise:

**Layer 1 (Stash model):** Instant save, zero friction. iOS Share Sheet as universal intake. Any app, any content type, three taps maximum.

**Layer 2 (Readwise model):** Optional resonance note + entity chips (3-4 most recently active characters/scenes). Not required, never blocking, but present when the moment of recognition is hottest.

### Two Fields, Not One
- `captureMethod` — closed enum: `share_sheet / direct / import / sync / manual`
- `sourceApp` — open string, auto-populated from Share Sheet metadata
- Never hardcode app names

### Storage Decision
JSON throughout (not plist). Primary: Supabase + pgvector for live system. File system as secondary sync target for Obsidian compatibility. Karen's content files stay human-readable. Object model lives in `.shopfloor/` hidden directory.

### Rename Detection
Correlation scan using macOS creation date + file size + partial content hash. Without this, a rename looks like a delete plus a create.

---

## Phase 4: Naming Decisions

- **Platform name:** "ShopFloor" — proposed by Bill, accepted immediately
- **Rationale:** A shop floor is where skilled people use organized tools to turn raw material into finished work. Implies stations (roles), floor management (Tier 1 skills), quality control (scorecards), reconfigurability for different verticals.
- **Hidden directory:** `.shopfloor/`
- **First vertical name:** "StoryEngine" — the fiction-specific configuration of the floor
- **"Roles" not "personas" or "employees":** Maps to real-world publishing team structure

---

## Phase 5: System Architecture

### Three-Level Hierarchy
```
ShopFloor (platform — the loom, vertical-agnostic)
  └── StoryEngine (fiction vertical — one pattern card)
        └── Team: collection of Roles
              ├── Developmental Editor → structure, pacing, beat-sheet skills
              ├── Copy Editor → grammar, style, POV discipline skills
              ├── Continuity Guard → timeline, setting, cast consistency skills
              └── Story Keeper → session-init, export, audit skills (infrastructure)
```
*Note: Role structure updated in April 14 session — see Session-2026-04-14.*

### The AI-Native App Model
Native iOS/macOS app (above waterline) + skill execution bridge + Claude API + write-back to `.shopfloor/`. "Same as Cursor but for fiction writing." Karen never sees a form — she has a conversation. The form fills in behind the scenes.

### Context Milk Problem
As a story grows, loading all object model records into every skill's context window degrades performance. Solution: each skill declares a `contextFingerprint` specifying exactly which records it needs (`all`, `linked`, `singleton`, `none`). Session-init reads the fingerprint and loads only what's declared.

### Skill Evaluation System
- Three modes: `warranty` (first N uses, default 10) → `active` (prompt every Nth use, default 3) → `passive` (observe only)
- `SKILL_OUTCOME` events: accepted/modified/ignored — always recorded
- `SKILL_FEEDBACK` events: Karen's 👍/👎 + optional `karensNote` free-text field (most actionable signal)
- `modification_threshold`: if Karen modifies output more than 40% of the time, skill flagged for review
- Scorecard per role per project tracks all of this

### Skill Designer as the Compiler
The most important skill in the system. Must know: SKILL.md format, tier system, context declaration rules, full object model, JSON schema conventions, audit contracts, and the iceberg principle. Must be written by hand (bootstrapping problem). Once written, skills become cheap to generate. Goal: Karen can eventually describe new skills in plain English.

---

## Phase 6: Data Structures

44 schema templates converted from `.txt` to Obsidian-compatible markdown with YAML frontmatter, wiki links, and tier callouts. 3 new Operations schemas created: `Role_Record.md`, `Scorecard.md`, `Team_Manifest.md`. Total: 46 schemas.

**Ackerman/Puglisi thesaurus series** (Emotion, Wound, Conflict thesauri) confirmed as backbone of character development skill layer. AI generates framework-shaped output fresh for each character — more useful than the books because the books give a type; the AI gives *this* character's specific instantiation.

---

## Phase 7: Bottlenecks (from ShopFloor Storage Spec Section 19)

1. Context window saturation — Critical
2. Write-back fan-out — High
3. Session-init overhead — High
4. Audit trail growth — Medium
5. **Mobile impedance — Critical, architectural** *(resolved in April 14 session — native app decision)*
6. Role routing ambiguity — Medium
7. **Skill Designer context hunger (19.7) — High** — mitigated by `schema-index.json` and `role-index.json`
8. Cross-reference integrity at scale — Medium
9. iCloud sync throughput — Medium
10. Scorecard staleness — Low

---

## Phase 8: File Migration

Everything moved from `~/Desktop/WriteTrack/WriteTrack/` to `~/Documents/Development/ShopFloor/`. Git repo initialized. gStack project slug migrated.

---

## Key Design Decisions (Do Not Relitigate Without Reason)

- Platform = ShopFloor (vertical-agnostic). First vertical = StoryEngine (fiction).
- Hidden dir = `.shopfloor/`. Product root = `StoryEngine/` in iCloud Drive.
- Capture is two-layer: Layer 1 = instant save (Stash model), Layer 2 = optional resonance note + entity chip (Readwise model).
- `captureMethod` is a closed enum; `sourceApp` is an open string. Never hardcode app names.
- `note_at_capture` is distinct from later classification notes — captures the "why" at the resonance moment.
- Tags are zero-required. AI classifies. Embeddings eliminate taxonomy overhead.
- The loom (ShopFloor) doesn't care what you weave. Keep horizontal and vertical layers cleanly separated.
- Native iOS/macOS app is the implementation path. Not file system as app.

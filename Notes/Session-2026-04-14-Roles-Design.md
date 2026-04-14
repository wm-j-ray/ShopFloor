# Session — Roles Design (Office Hours)
**Date:** April 14, 2026
**Session type:** Office Hours — design session
**Conducted under:** gStack (office-hours)

---

## What We Did

Ran a full /office-hours session on "Roles Design" — the open question of how the five roles function at runtime. Followed with a live AE intake exercise using a real particle.

---

## Key Design Decision: Project-State Model

The active role for any project is determined by the project's pipeline state, not by Karen's words.

- Eliminates intent-parsing from routing
- Publisher cannot be bypassed — it only activates when `pipeline_state = pitched`
- State machine is deterministic and auditable

This was chosen over:
- **Pipeline Model** (artifacts pass between roles — adds friction, breaks "conversational throughout")
- **Single-Conversation Model** (role switches mid-thread — routing too hard, failure invisible)

---

## Decisions Locked This Session

1. **Project-State Model** is the routing architecture.
2. **Publisher is Tier 2+ only.** Tier 1 (Prompt Cookbook) delivers AE-only prompts. Greenlight decisions require Hyperdrive. Rationale: pasting a Publisher evaluation rubric into a general-purpose AI inherits the sycophancy the architecture was designed to prevent.
3. **AE captures `intent_context` and `abandonment_history` during intake.** Publisher reads these from the project record — never re-asks Karen.
4. **`revise-and-resubmit` is a transient event**, not a resting state. It writes `pipeline_state` back to `draft`.
5. **`deferred` is a stable resting state.** AE remains active. Resurfaces after 3 sessions without activity. Does not count toward `active_project_count` for Publisher capacity gate.
6. **Managing Editor has no voice toward Karen.** When disambiguation is needed, the active role for the most recently active project asks the question — not the Managing Editor directly.
7. **AE tracks Swain element slot-fill in the project record**, not in conversation context alone. Enables cross-session resume without losing progress.
8. **Publisher warranty detection:** If Publisher greenlights >8 out of 10 pitches during the warranty period, a review flag surfaces to Bill. Threshold configurable via `system-manifest.json`.

---

## Eureka: Sycophancy as Architecture Problem

AI sycophancy in creative writing is an architecture problem, not a prompting problem.

The market's fix: "remind the AI to be critical." This is fragile and user-side — it breaks every session and requires Karen to fight the AI.

ShopFloor's fix: role-separated systems with per-role agendas baked into SKILL.md. The Publisher has no agreeable path by design. Sycophancy becomes a configuration bug rather than a model failure.

No one has built this. Sudowrite, HyperWrite, ChatGPT with system prompts — all ad-hoc role prompting. ShopFloor is role separation as architecture.

---

## AE Intake Exercise

Ran a live AE intake on a real particle: an AP News quote about Section 230 ("twenty-six words tucked into a 1996 law..."). Full intake completed. The story that emerged:

> A grieving single mother must expose the wealthy family responsible for her daughter's death despite a powerful law firm, an institution protecting its star athlete, and platforms legally shielded from accountability — or watch her daughter's memory destroyed by the very system that killed her.

Key observations from the exercise:
- **The Threatening Disaster is the hardest Swain slot.** The user knew something was missing ("I don't think that's enough to lose") but couldn't get there alone. This is where the AE earns its keep.
- **"I'm dying here" was the hold-the-line moment.** That's when the idea felt alive and the impulse was to skip ahead to the Starting Line-Up. A sycophantic AI generates there. The AE doesn't.
- **"So what do you think?" is a required AE output**, not optional. The synthesis/assessment at the end — naming what's strong, what's unresolved, what the story is actually arguing — must be a mandatory closing move in the SKILL.md.
- Intake ran approximately 10–15 minutes, 8–10 exchanges. That's the context budget reality.

---

## New Artifact: Project.md

Created `Data Structures/Operations/Project.md` (v1.0).

Covers the AE and Publisher phases. Key fields:
- `pipeline_state` — resting state in the pipeline
- `active_role` — set by Managing Editor at session start
- `swain_elements` — slot-fill tracker (all null until surfaced; AE withholds SLU until all five non-null)
- `intent_context` — `why_this_idea`, `why_now`, `character_relationship`
- `abandonment_history` — array of prior attempts with `tried_before`, `stopped_because`, `attempt_date`, `attempt_label`
- `deferred_session_count` — triggers resurfacing at 3
- `publisher_decision`, `publisher_decision_date`, `publisher_note`

Developmental Editor and Proofreader phase fields are stubs — to be added when those roles' skills are designed.

---

## Updated "What's Next" Order

The prerequisite ordering shifted this session:

1. ~~Generate `schema-index.json`~~ (deferred — Skill Designer not yet needed)
2. ~~Generate `role-index.json`~~ (deferred — same reason)
3. **Write `Skills/creative/starting-lineup/SKILL.md`** — first proof-of-concept skill (AE intake skill)
   - Prerequisite: `Project.md` schema ✓ (written this session)
   - Prerequisite: confirm `Data Structures/Operations/` has a project record schema ✓
4. **Write `Skills/creative/skill-designer/SKILL.md`** — the meta-skill

The routing skill (`Managing Editor`) can be deferred until after AE and Publisher skills are functional. Cold-start routing (new particle → AE) is hardcoded behavior, not a routing skill invocation.

---

## Design Doc

Full design doc (approved, 3 rounds of adversarial review, score ~9/10):
`~/.gstack/projects/wm-j-ray-ShopFloor/wmjray-main-design-20260414-140434.md`

---

## Session Rule Reminder

Every session: conducted under gStack, decisions written to Notes/, committed and pushed.

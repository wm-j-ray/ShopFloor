# Session Notes — 2026-04-14 — Publisher Design + Greenlight Review

## Summary

Designed the Publisher's judgment model and wrote `greenlight-review` SKILL.md (Tier 3). Also wrote `System_Manifest.md` schema template to close a referenced-but-undefined gap. Continued from the Skill Designer session; context compacted mid-session.

---

## Files Created or Updated

| File | Action | Notes |
|------|--------|-------|
| `Data Structures/Operations/System_Manifest.md` | Created | v1.0 — active_project_count, quality_control thresholds |
| `Skills/creative/greenlight-review/SKILL.md` | Created | v1.0 — Publisher go/no-go, four evaluation criteria |
| `.shopfloor/skill-registry.json` | Updated | Added greenlight-review entry (3 skills total) |
| `CLAUDE.md` | Updated | Items 9 and 11 marked complete; skill counts updated |

---

## Publisher Judgment Model — Four Criteria

Designed before writing the SKILL.md. All four are in the skill.

1. **Structural Completeness** — Are all five Swain elements specific and strong? Hard blocks: vague Threatening Disaster (non-negotiable), abstract Objective (flagged). Criterion 1 is the floor — the Starting Line-Up must pass this before anything else counts.

2. **Abandonment Pattern** — Has Karen tried this idea before? Does the current Starting Line-Up address what stopped her? The one clarifying question the Publisher is allowed to ask: "What's different this time?" This is where AI can do real work — no other tool tracks this.

3. **Investment Signal** — `intent_context` fields: why_this_idea, why_now, character_relationship. The Publisher reads the AE's collected answers. Does not re-interview Karen. "Why now" that is a circumstance ("I have time") vs. a pull ("this character has been in my head for three years") — the difference matters. Null intent_context = hard block → revise-and-resubmit to AE.

4. **Portfolio Capacity** — `active_project_count` from system-manifest + `last_active_timestamp` on active projects. Thresholds: 0–1 = no concern, 2 = note it, 3+ = DEFERRED unless investment signal is exceptional. The "whip and chair" dimension: a greenlit that Karen can't finish is not a gift.

**User confirmation on these criteria:** "Your points 1–4 are spot on. Points 2–4 are a true differentiator. Particle proximity (future signal) is where the 'books on writing craft' say it matters and no tools actually quantify it. Points 2 and 4 link together — this is where AI can speak to Karen, learn from what she's kissed off previously, and keep her on track."

---

## Key Design Decisions

**Publisher derives portfolio picture inline** (confirmed by user). Reads Project records directly — pipeline_state + last_active_timestamp. No pre-computed "Karen profile" in v1. Finishing rate is a future capability (see gap below).

**Particle proximity is future Tier 2** — requires a `particle-cluster-analyzer` pre-processing skill to avoid blowing Publisher context budget. The Publisher notes its absence but does not approximate it inline.

**Publisher decisions do not require Karen's confirmation before write-back.** The decision is the output — write-back is immediate. Unlike the AE's Starting Line-Up, which Karen must accept, the Publisher's decision is rendered and committed.

**active_role on greenlit written by this skill directly** (exception to the general rule that Managing Editor sets active_role). Rationale: avoid routing gap before the next session. Publisher writes `active_role → developmental_editor` on greenlit only.

---

## Design Gap Flagged

**No `completed` pipeline state in Project schema v1.0.** After `greenlit`, a project goes through developmental editing and proofreading, then... stays `greenlit` forever. There is no `completed` or `archived` resting state. This means:
- `active_project_count` cannot distinguish between a project Karen is actively writing and one she finished five years ago
- Finishing rate (Karen's ratio of started-to-finished books) cannot be accurately computed
- The Publisher's portfolio analysis relies on `last_active_timestamp` as a proxy for dormancy

**Resolution:** Add `completed` pipeline state to Project schema v2.0. Until then, flagged as a Bill-review note in `greenlight-review` SKILL.md.

---

## System_Manifest.md — Key Decisions

- Singleton at `.shopfloor/system-manifest.json`
- Written by Managing Editor only (scorecard-updater, session-init)
- Quality control defaults: warranty_target=10, modification_threshold=0.40, publisher_warranty_greenlight_max=0.80, active_evaluation_interval=3
- `deferred` projects do NOT count toward `active_project_count` — only `greenlit` projects count
- Gap noted in Notes section: no `completed` state yet

---

## What's Next

| Item | Priority | Notes |
|------|----------|-------|
| Add `writable_by` to all 46 schema templates | Low | Values already in schema-index.json; no running code depends on it yet |
| Add `completed` pipeline state to Project schema v2.0 | Medium | Required for accurate finishing-rate in Publisher portfolio analysis |
| Write `particle-cluster-analyzer` Tier 2 skill | Future | Particle proximity signal for Publisher. Requires its own design session |
| Write Tier 1 floor management skills | Future | session-init, routing, scorecard-updater, orphan-manager, etc. |
| Write Tier 2 quality control skills | Future | character-arc-checker, conformance-reporter, timeline-validator, etc. |

---

## Scope Note

The user flagged "spec-creeping territory" mid-session. The distinction made:
- **Necessary before writing the SKILL.md:** whether Publisher uses inline portfolio analysis or a pre-computed profile (architectural — affects contextFingerprint). Resolved: inline.
- **Resolvable in the SKILL.md itself:** voice design for the "whip and chair" moment, specific framing for abandonment pattern language. Both handled in Conversation Flow and Output Format sections.
- Particle proximity and finishing rate are real architectural gaps — not spec creep. Documented and deferred appropriately.

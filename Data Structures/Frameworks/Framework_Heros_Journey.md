---
schema_type: heros_journey
category: framework
vertical: storyengine
template_version: "1.0"
profile_version: ""
date_instantiated: ""
status: template
priority: 1
linked_schemas:
  - Framework_Selector
  - Beat_Registry
  - Conformance_Report
  - Story_Spine
writable_by:
  - managing_editor
narrative_threads: []
---

# Hero's Journey

> **Purpose:** Defines the 12-stage structural sequence of Joseph Campbell's Hero's Journey as adapted by Christopher Vogler for use in the Beat Registry and Conformance Report.
>
> **Instance naming:** When creating an instance, save as `[ID]_Name.md`, set `profile_version` and `date_instantiated`.

> 🔴 **TIER 1 — Core engine.** Complete before drafting begins.

---

## Framework Orientation

| Field | Value |
|-------|-------|
| Created By | Joseph Campbell (mythic theory) / Christopher Vogler (fiction adaptation) |
| Source | The Hero with a Thousand Faces (Campbell, 1949) / The Writer's Journey (Vogler, 1992) |
| Best Suited For | Mythic, epic, speculative, and coming-of-age fiction. Any story where the |
| Not Ideal For | Tight domestic realism, ensemble works without a clear central hero, or |
| Core Principle | The hero leaves a known world, enters an unknown world, survives an ordeal, |
| Number of Stages | 12 |
| Required Stages | 9 |
| Optional Stages | 3 |

protagonist undergoes a transformative journey — literal or internal — and returns changed.
stories where transformation is deliberately refused or ironic.
and returns transformed. The journey is both external (physical) and internal (psychological).
Every stage has a mythic function that resonates across cultures.

## Common Failure Modes

1. The Ordeal is underpowered — it must be a genuine death-and-rebirth moment, not merely
a difficult scene. If the hero does not fundamentally break, the Road Back has nothing to carry.
2. Mentors are overused — the mentor exists to equip the hero, not to solve problems for them.
A mentor who rescues the hero at key moments undermines the hero's agency.
3. The Return is rushed or omitted — the hero's re-integration into the ordinary world is
where the transformation is proved. Skipping it leaves the journey thematically incomplete.

## Stage Definitions

| Beat ID | Beat Label | Required | Act | Target Position | Definition | Common Error |
|---|---|---|---|---|---|---|
| BT-001 | Ordinary World | yes | 1 | 0-10% | Establishes the hero's normal life, their flaw or lack, and the world they inhabit before the adventure begins. The reader must understand what is at stake in this world. | So much time spent here that the Call to Adventure arrives too late. |
| BT-002 | Call to Adventure | yes | 1 | 10-15% | An event, person, or revelation presents the hero with a challenge or quest that will disrupt the ordinary world. The status quo becomes untenable. | The call is too mild — it does not create genuine urgency or change of state. |
| BT-003 | Refusal of the Call | no | 1 | 15-20% | The hero hesitates, doubts, or outright refuses the challenge. Establishes the cost of the journey and the hero's vulnerability. | Omitted entirely, making the hero seem fearless rather than human. |
| BT-004 | Meeting the Mentor | no | 1 | 20-25% | The hero encounters a figure who provides guidance, equipment, or wisdom needed for the journey ahead. The mentor prepares but does not accompany. | The mentor solves problems that the hero should solve — removing agency from the protagonist. |
| BT-005 | Crossing the Threshold | yes | 1 | 25% | The hero commits to the adventure and enters the Special World — a realm with different rules, dangers, and values than the ordinary world. Point of no return. | The threshold is crossed passively; the hero is pushed rather than choosing to cross. |
| BT-006 | Tests, Allies, Enemies | yes | 2 | 25-50% | The hero navigates the Special World — learning its rules, forming alliances, identifying enemies, and being tested. Preparation for the central ordeal. | Treated as a series of disconnected episodes rather than a progressive escalation of stakes. |
| BT-007 | Approach to Inmost Cave | yes | 2 | 50% | The hero and allies prepare for the major challenge ahead. A threshold moment before the central crisis. Often involves a setback, a plan, or a moment of doubt. | Skipped — the hero moves directly from tests to ordeal without this moment of anticipation. |
| BT-008 | Ordeal | yes | 2 | 55-60% | The central crisis — a death and rebirth moment. The hero faces their greatest fear, confronts the antagonist force directly, and appears to fail or die before being reborn changed. | The ordeal is physical only; the internal transformation — the death of the old self — is absent. |
| BT-009 | Reward | yes | 2 | 60-65% | The hero survives the ordeal and claims the reward — an object, knowledge, reconciliation, or new power. A moment of elation before the journey home. | The reward is trivial or disconnected from the hero's central wound or need. |
| BT-010 | The Road Back | yes | 3 | 65-80% | The hero begins the return journey, but the consequences of the ordeal pursue them. The antagonist force makes a final attempt to reclaim what was taken. | Treated as a plot formality rather than a genuine escalation; stakes drop instead of rising. |
| BT-011 | Resurrection | yes | 3 | 80-90% | The climax — a final test where the hero must demonstrate that the transformation from the ordeal is real. A second death-and-rebirth, now fully conscious. | Confused with the Ordeal; the Resurrection must be a separate, final proof of change. |
| BT-012 | Return with Elixir | no | 3 | 90-100% | The hero returns to the ordinary world carrying something of value — knowledge, healing, a literal object — that benefits the community left behind. | The hero returns empty-handed or unchanged in their relationship to the ordinary world. |

One entry per stage. Load directly into Beat Registry.

## Framework Notes

The Hero's Journey is a mythic template, not a rigid beat sheet. Stages can overlap,
compress, or expand depending on genre and story length.
In interior or psychological stories, the Special World is a state of mind, not a
physical location. The journey is inward.
Vogler's 12-stage adaptation is more prescriptive than Campbell's original — use
Vogler for fiction drafting, Campbell for deeper mythic research.
The Refusal of the Call (BT-003), Meeting the Mentor (BT-004), and Return with
Elixir (BT-012) are marked optional — they are mythically significant but not
structurally mandatory for a functional story.

## Notes

*No notes yet.*

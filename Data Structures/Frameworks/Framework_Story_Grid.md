---
schema_type: story_grid
category: framework
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
narrative_threads: []
---

# Story Grid

> **Purpose:** Defines a simplified beat sequence drawn from Shawn Coyne's Story Grid methodology for use in the Beat Registry and Conformance Report.
>
> **Instance naming:** When creating an instance, save as `[ID]_Name.md`, set `profile_version` and `date_instantiated`.

> 🔴 **TIER 1 — Core engine.** Complete before drafting begins.

---

## Framework Orientation

| Field | Value |
|-------|-------|
| Created By | Shawn Coyne |
| Source | The Story Grid (2015) |
| Best Suited For | Writers who want a rigorous, genre-aware diagnostic system. Especially |
| Not Ideal For | Writers in early ideation who need creative flexibility rather than |
| Core Principle | Every story is defined by its genre, which creates a set of reader |
| Note | This template simplifies the full Story Grid system for Beat Registry compatibility. |
| Number of Beats | 10 |
| Required Beats | 8 |
| Optional Beats | 2 |

strong for genre fiction where reader expectations are a defined contract. Works well
for revision — the Story Grid is designed as much for fixing a broken story as for
building one from scratch.
diagnostic precision. The full Story Grid system is extensive; this simplified version
captures its core structural logic.
expectations (conventions and obligatory scenes) that must be honored. The story is
driven by Five Commandments at both the scene level and the global level. Change is
measured by a value shift — from positive to negative or negative to positive — at
every unit of story.
For the complete methodology including the Content Grid and genre analysis, consult
Coyne's source material.

## Common Failure Modes

1. The obligatory scenes for the chosen genre are missing — every genre has specific
scenes readers require. A thriller without a hero-at-the-mercy-of-the-villain scene
fails its contract. Identify your genre's obligatory scenes before drafting.
2. Value shifts are flat — every scene must shift a core value (life/death, love/hate,
justice/injustice) from positive to negative or negative to positive. Scenes that end
where they began are dead weight.
3. The global controlling idea is absent — the story must argue something. The resolution
must prove or disprove the controlling idea through action, not declaration.

## Beat Definitions

| Beat ID | Beat Label | Required | Act | Target Position | Definition | Common Error |
|---|---|---|---|---|---|---|
| BT-001 | Inciting Incident (Global) | yes | 1 | 10-20% | The event that disrupts the protagonist's life and sets the global story in motion. Introduces the core value at stake and shifts it from its opening state. Must be causal — everything that follows traces back to this moment. | Too minor to carry the weight of a global story launch; reader does not feel the stakes. |
| BT-002 | Genre Conventions Established | yes | 1 | 0-25% | The setting, tone, character types, and world rules specific to the story's genre are established early enough that the reader knows what kind of story they are reading. | Genre signals are mixed or absent; reader cannot calibrate expectations. |
| BT-003 | Progressive Complications | yes | 2 | 20-75% | A series of scenes each of which shifts a core value and raises the stakes beyond the previous scene. Each complication must be causally connected — and then is not acceptable; but therefore and but however are required. | Scenes accumulate without escalating; the story runs at a single pitch. |
| BT-004 | Midpoint Shift | no | 2 | 50% | A significant reversal at the story's center that changes the protagonist's understanding of the situation or forces a strategy change. The stakes become personal if they were external, or external if they were internal. | Absent or too mild; the second half of the story mirrors the first rather than escalating. |
| BT-005 | Crisis (Global) | yes | 2 | 70-80% | The best bad choice or irreconcilable goods — the moment the protagonist faces a decision between two options, both of which carry significant cost. The decision must be genuinely difficult; an easy choice is not a crisis. | The protagonist has an obvious correct answer; the decision carries no real cost. |
| BT-006 | Obligatory Scene(s) | yes | 2-3 | varies | The scene or scenes the reader of this genre requires. Defined by genre — a love story requires a declaration of love, a thriller requires a confrontation at the villain's mercy, a horror story requires a monster reveal. | Identified incorrectly or omitted; the genre contract is broken. |
| BT-007 | Climax (Global) | yes | 3 | 80-95% | The protagonist acts in response to the crisis decision. The action must be consistent with the decision made and must shift the global core value to its final state. The story's controlling idea is proven or disproven here. | The climax is passive — the protagonist witnesses resolution rather than driving it. |
| BT-008 | Resolution (Global) | yes | 3 | 95-100% | The final value state of the story is established. The controlling idea — the story's argument — is made clear through the outcome. What the protagonist gained or lost, and what it means, is evident without being stated. | The controlling idea is stated rather than demonstrated; the writer explains the meaning instead of showing it. |
| BT-009 | Controlling Idea | yes | — | global | The story's core argument expressed as: [value] [positive or negative] because [reason]. Not a theme topic but a complete cause-and-effect statement. Drives every global-level decision. Example: "Love prevails when two people choose honesty over self-protection." | Stated as a topic (love, justice) rather than as a complete argument with a causal claim. |
| BT-010 | Beginning Hook | no | 1 | 0-20% | An opening sequence — distinct from the full Act 1 — designed to hook the reader by establishing the protagonist's world, introducing the inciting incident, and demonstrating the story's value proposition before the reader can disengage. | The hook buries the inciting incident; the opening pages offer no reason to continue reading. |

One entry per beat. Load directly into Beat Registry.

## Framework Notes

| Field | Value |
|-------|-------|
| The Story Grid operates at two levels simultaneously | the global story level (tracked |

here) and the scene level. At the scene level, every scene has its own Five
Commandments (inciting incident, progressive complication, crisis, climax, resolution).
The Scene Container template in the Verb layer captures scene-level structure.
Obligatory Scenes (BT-006) are genre-specific. Before populating the Beat Registry,
identify your genre and list its obligatory scenes. These become required beats.
The Controlling Idea (BT-009) is not a scene — it is a global structural constraint.
It is listed here so it can be registered and tracked, but it has no target position.
Value tracking — recording the core value shift in every scene — is the Story Grid's
most powerful diagnostic tool. Use the Scene Container's Narrative Function section
to track value shifts at the scene level.

## Notes

*No notes yet.*

---
schema_type: character_profile
category: noun
vertical: storyengine
template_version: "2.1"
profile_version: ""
date_instantiated: ""
status: template
linked_schemas:
  - Relationship_Profile
  - Group_Profile
  - Wound_Profile
  - POV_Profile
writable_by:
  - developmental_editor
narrative_threads: []
---

# Character Profile

> **Purpose:** Captures the full identity, psychology, narrative function, and voice of a single character in a work of fiction.
> **Instance naming:** When creating a character, save as `CHR-001_Firstname_Lastname.md` and update `profile_version` and `date_instantiated`.

---

## Identity

| Field | Value |
|-------|-------|
| Character ID | |
| Character Name | |
| Aliases / Nicknames | |

---

## Origin & Basics

| Field | Value |
|-------|-------|
| Date of Birth | |
| Place of Origin | |
| Pronouns / Gender Identity | |
| Sexual Orientation | |
| Occupation / Social Class | |
| Languages Spoken | |
| Religion / Belief System | |

---

## Appearance

| Field | Value |
|-------|-------|
| Height / Build | |
| Style / Fashion | |
| Voice / Speech Quality | |
| Distinctive Physical Features | |
| Body Language / Gait | |
| Film Reference — Most Like | |

> **How to use:** Describe the character in plain language or name an actor/film still. The system will find the reference image and populate this field. Example: *"Linda Hamilton in Terminator 2, holding the machine gun."*

---

## Role in Story

| Field | Value |
|-------|-------|
| Narrative Role | `protagonist` / `antagonist` / `deuteragonist` / `foil` / `catalyst` / `witness` / `other` |
| Core Motivation | |
| Primary External Conflict | |
| Primary Internal Conflict | |
| Short Arc Summary | |
| Thematic Function | |

---

## Emotional Wound

> Linked schema: [[Wound_Profile]]

| Field | Value |
|-------|-------|
| Wound ID | |
| Core Wound / Defining Past Event | |
| False Belief It Created | |
| Coping Mechanisms | |
| Triggers | |
| How It Shapes Current Behavior | |
| Healing / Shift Point (if any) | |

> **How to use:** Describe the wound in plain language. The system will suggest a structured [[Wound_Profile]] instance using Ackerman/Puglisi thesaurus data. You confirm, adjust, reject.

---

## Identity & Persona

| Field | Value |
|-------|-------|
| Public Self | |
| Private Self | |
| Masks or Personas Worn | |
| What They Conceal | |
| How They View Themselves | |
| How Others View Them | |
| Labels They Embrace or Reject | |

---

## Relationships

> Linked schema: [[Relationship_Profile]]

| Relationship ID | Character ID | Nature of Bond | Power Dynamic |
|----------------|-------------|----------------|---------------|
| | | | |

**Group Membership:** (link to [[Group_Profile]] instances)

---

## Influences & Anchors

| Field | Value |
|-------|-------|
| Cultural or Personal Icons | |
| Sentimental Objects | (link to [[Object_Profile]] if applicable) |
| Grounding Habits or Rituals | |
| Media / Art That Shapes Them | |

---

## Voice & Dialogue Markers

| Field | Value |
|-------|-------|
| Tone | |
| Vocabulary / Syntax / Fillers | |
| Speech Patterns or Quirks | |
| Topics They Gravitate To | |
| Topics They Avoid | |
| Style of Humor | |

---

## Setpiece Potential

| Field | Value |
|-------|-------|
| Settings That Belong to This Character | (link to [[Location_Profile]] instances) |
| Scene Types That Emerge Organically | |
| What a Silent Scene Would Convey | |

---

## Timeline Snapshots

| Field | Value |
|-------|-------|
| Key Life Events Before Story Begins | |
| Milestones During Story | |
| Relationship or Identity Shifts Over Time | |

---

## Particles

> Particles linked to this character. Populated automatically as particles are tagged to this Character ID.

| Particle ID | Capture Date | Preview | Status |
|-------------|-------------|---------|--------|
| | | | |

---

## Conformance Notes

> AI-generated observations from prose analysis. Updated after each significant draft pass.

*No conformance notes yet.*

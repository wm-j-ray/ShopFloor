# ShopFloor — Skill Designer Specification
**Version:** 1.0 (Design Phase)  
**Status:** Pre-implementation — depends on ShopFloor Storage Spec v1.0  
**Author:** Bill (architecture), Claude (documentation)  
**Date:** 2026-04-12  
**Classification:** Foundational. Required before any SKILL.md file is written.

---

## 1. Purpose and Scope

The Skill Designer is a meta-skill — a skill that creates other skills. It translates intent (what someone needs the shop floor to do) into a conforming SKILL.md file the platform can execute.

This document specifies:

1. **What a well-formed skill is** — the SKILL.md format, required sections, and validation rules
2. **How the Skill Designer operates** — conversation flow, two entry points, output artifacts
3. **Who uses it and how** — Bill's developer mode versus Karen's writer mode
4. **How created skills are validated and installed** — the review gate and skill-installer pipeline
5. **How the feedback loop works** — scorecard → Skill Designer → improved skills
6. **The meta-bottleneck mitigation** — how the Skill Designer manages its own context hunger

This document does not specify individual skill content. Character-creation, wound-intake, beat-sheet, and other skills are out of scope here. This document specifies only what any well-formed skill must be.

---

## 2. Design Goals

These goals are ordered by priority. When they conflict, the higher-numbered goal yields.

**2.1 Karen-accessible.** A non-technical writer can describe what she needs in plain English and receive a working skill. She does not write code, does not edit YAML, does not understand what a context fingerprint is. The Skill Designer translates her felt need into a technical artifact without exposing her to the machinery.

**2.2 Bill-efficient.** A developer can work quickly, specify technical details directly, and skip conversational scaffolding he doesn't need. The Skill Designer serves both users without making either one wait for the other's experience.

**2.3 System-learnable.** The Skill Designer reads performance data (scorecards, audit events) and identifies skills that need improvement. In v1, this surfaces as a structured report. In v2+, it surfaces as proactive suggestions. The architecture for learning is in place from day one.

**2.4 Self-constraining.** The Skill Designer must be the most context-efficient skill on the floor. It loads compressed reference indexes, not full schemas. It requests full records only when needed for a specific operation. Its own context footprint is a hard design constraint, not a soft preference.

**2.5 Quality-gating.** The Skill Designer validates its own output before surfacing it. A skill with a failed validation check does not leave the Skill Designer. The floor does not accept incomplete work.

---

## 3. The SKILL.md Format

Every skill on the ShopFloor platform is a SKILL.md file. It is the instruction set the AI follows when a skill is invoked. It is not code — it is a structured natural language document that Claude processes as a system prompt.

The SKILL.md format is the contract between the skill author and the platform. A skill that conforms to this format can be validated, installed, versioned, tracked, and improved. A skill that does not conform cannot be trusted by the floor.

### 3.1 Required Sections

A well-formed SKILL.md must contain all nine sections, in this order:

```
## 1. Identity
## 2. Purpose
## 3. Context Requirements
## 4. Responsibilities
## 5. Conversation Flow
## 6. Output Format
## 7. Write-Back Contract
## 8. Guardrails
## 9. Validation Checklist
```

No section may be omitted. No section may be empty. The order is fixed.

### 3.2 YAML Frontmatter

Every SKILL.md begins with a YAML frontmatter block:

```yaml
---
skill_id: character-creation
skill_name: Character Creation
version: "1.0"
tier: 3
role: dev-editor
deployment_targets:
  - mobile
  - desktop
requires_ai: true
status: draft | review | active | deprecated
date_created: ""
date_modified: ""
authored_by: bill | karen | skill-designer
inputs:
  - resource: Character_Profile
    scope: active        # active | linked | system | all | project-root | global | skill-specific
    required: true
  - resource: Wound_Profile
    scope: linked
    required: false
outputs:
  - resource: Character_Profile
    action: create       # create | update | create-or-update | append
---
```

All fields are required. `authored_by` records the original creator — used for accountability tracking and review routing.

**`inputs`** — machine-readable summary of the skill's context requirements (mirrors Section 3 of the SKILL.md body). Used by session-init and the transaction-manager to plan writes before execution begins. Each entry:
- `resource` — the data structure, file, or system resource name (e.g., `Character_Profile`, `manifest`, `VERTICAL.md`, `schema-index`)
- `scope` — where it lives: `active` (current project's active record), `linked` (referenced by another record), `system` (platform infrastructure), `all` (all records of this type in the project), `project-root` (file at repo root), `global` (cross-project path), `skill-specific` (conditional — only in certain modes)
- `required` — `true` if the skill cannot run without this resource; `false` if optional

**`outputs`** — machine-readable summary of the skill's write-back contract (mirrors Section 7 of the SKILL.md body). Used by the transaction-manager to pre-write the pending transaction file before any writes begin. Each entry:
- `resource` — the data structure or file being written
- `action` — `create` (new record), `update` (modify existing), `create-or-update` (upsert), `append` (add to log or array)

`inputs` and `outputs` must stay in sync with Section 3 (Context Requirements) and Section 7 (Write-Back Contract). If those sections change, update the frontmatter. The Skill Designer validates this consistency as part of its output check.

### 3.3 Section Specifications

---

#### Section 1 — Identity

A single paragraph, plain English, written for Karen. No technical jargon. Answers three questions: what does this skill do, who is responsible for it (which role), and when would Karen reach for it?

Length limit: 150 words. If it cannot be explained in 150 words, the skill is doing too many things.

---

#### Section 2 — Purpose

The *why*. What problem does this skill solve? What outcome does Karen receive that she wouldn't have without it? One to three sentences maximum.

---

#### Section 3 — Context Requirements

Machine-readable. Specifies exactly what the skill needs loaded before execution. This section is processed by session-init before the conversation begins. The `contextFingerprint` in the skill registry mirrors this section exactly — the registry copy exists so session-init can make loading decisions without opening every SKILL.md.

Format:

```
| Resource | Scope | Required | Notes |
|----------|-------|----------|-------|
| Character_Profile | active | yes | characters currently in scope |
| Wound_Profile | linked | no | linked to active characters |
| Scene_Container | active | yes | scene being developed |
| manifest | system | yes | always required |
| session-state | system | yes | always required |
```

**Scope values:**

| Value | Meaning |
|-------|---------|
| `active` | Currently open or selected by Karen |
| `linked` | Records linked to the active resource via foreign key |
| `all` | All records of this type in the project |
| `all(max:N)` | All records, up to N most recently modified |
| `system` | Always loaded; not user-data dependent |

**Context budget guidance:**
- Tier 1 (floor management): < 8K tokens total context load
- Tier 2 (quality control): < 10K tokens total context load
- Tier 3 (production): < 12K tokens total context load

If a skill's estimated context load exceeds its tier budget, the Skill Designer flags this as a warning. Bill decides whether to proceed. Karen is told in plain English: "This skill needs a lot of information to work well. It may run more slowly on large projects."

---

#### Section 4 — Responsibilities

Plain English. Two subsections — what this skill does, and what it explicitly does not do. Both are required.

```
This skill:
- Does X
- Does Y
- Does Z

This skill does NOT:
- Try to do A (that belongs to [other-skill])
- Modify B without asking first
- Persist anything Karen hasn't confirmed
```

The "Does NOT" list defines the edges. Every skill must have edges. Skills without defined edges expand into territory they were not designed for. The "Does NOT" list is not optional, not a courtesy — it is a structural requirement.

---

#### Section 5 — Conversation Flow

The conversational structure the skill follows. Not a script — a map. Explicit STOP points mark where the AI must wait for Karen's response before proceeding.

```
1. Opening move — how the skill announces itself and what it asks first
2. Information gathering — what it may ask, in what order
3. STOP: Wait for Karen's response
4. Analysis — what the skill evaluates
5. Presentation — how it formats and delivers findings
6. STOP: Karen accepts, modifies, or ignores
7. Write-back trigger — the event that initiates persistence
8. Confirmation — what Karen sees after write-back completes
```

**STOP points are structural, not cosmetic.** They are the moments where Karen is in control. At a STOP, the AI has said everything it has to say and is waiting. It does not fill silence with elaboration.

**Required:** at least one STOP must appear before any write-back operation. No skill may persist data without Karen having a clear opportunity to decline.

---

#### Section 6 — Output Format

Two outputs are defined separately. Both are required.

**Conversational output:** What Karen reads. Tone description, format guidance, length guidance, and a representative example.

**Structured output:** What the app parses when executing the write-back contract. Defined as a JSON schema. The app parses the structured output — not the conversational output — when executing writes.

Minimum schema:
```json
{
  "skill_output": {
    "action": "create | update | link | flag | none",
    "entity_type": "[schema type — e.g., Character_Profile]",
    "entity_id": "[entity ID or null for creates]",
    "fields_changed": {},
    "confidence": 0.0,
    "requires_confirmation": true
  }
}
```

Skills that produce multiple outputs (e.g., create a character and link a wound) must define a `skill_outputs` array. The singular form `skill_output` is for single-entity operations only.

---

#### Section 7 — Write-Back Contract

Precisely defines what gets written to the object model, and when. Any field this skill can create or modify must be listed here. No surprise writes.

```
On CONFIRMED output:
- Creates/Updates: [schema type], fields [exhaustive list]
- Links: [from schema type] → [to schema type] via [field name]
- Does NOT touch: [explicit list of fields this skill leaves alone]

On IGNORED output (Karen declines):
- Nothing written
- Log: SKILL_OUTCOME event with outcome=ignored

Audit events:
- SKILL_INVOKED (on session start)
- SKILL_OUTCOME with outcome=accepted | modified | ignored (on Karen's response)
```

The "Does NOT touch" list is as important as the writes. A skill that silently leaves fields alone is trustworthy. A skill that might modify unexpected fields is not.

---

#### Section 8 — Guardrails

Explicit prohibitions and safety rules. Four rules are universal — every skill carries them:

1. Never persist without Karen's confirmation (or a system-level auto-confirm rule explicitly defined in the Write-Back Contract)
2. Never create duplicate entity IDs
3. Never write to a file Karen is currently editing
4. Never modify a field marked `[locked]` in the schema

Additional guardrails are skill-specific. The Skill Designer prompts for them during construction.

---

#### Section 9 — Validation Checklist

A self-contained machine-checkable list of conditions. Used by the Skill Designer to validate output before surfacing. Also used during skill review and version upgrades.

```
[ ] Frontmatter complete — all required fields present
[ ] skill_id is kebab-case and unique in the skill registry
[ ] Identity section present and under 150 words
[ ] Context Requirements section present and parseable as a table
[ ] Responsibilities section present with explicit "Does NOT" list
[ ] Conversation Flow present with at least one STOP before write-back
[ ] Output Format defines both conversational and structured output
[ ] Structured output schema is valid JSON schema
[ ] Write-Back Contract present with explicit field list and "Does NOT touch" list
[ ] Guardrails section present with at least the four universal rules
[ ] Context fingerprint within tier budget
[ ] Deployment target declared
[ ] No overlapping responsibilities with other skills in this role — verified against ROLE.md
[ ] Version history comment block present below frontmatter
```

---

## 4. Two Entry Points: Bill and Karen

The Skill Designer operates in one of two modes. The mode is inferred from the opening message, not declared.

### 4.1 Bill Mode (Developer Entry)

Bill knows the system. He knows the tier, the role, the context fingerprint. He may have a draft already.

In Bill mode, the Skill Designer:
- Skips orientation questions
- Accepts technical specifications directly
- Validates against the SKILL.md format
- Flags gaps and asks only about what is missing
- Outputs a complete draft with a validation report

**Entry signal:** Technical vocabulary. "I want to build a Tier 3 skill for the dev-editor that does X" or "Here's a draft, can you validate it?" or "The beat-sheet skill's midpoint analysis is wrong — let's fix it."

**Bill mode flow:**
1. Acknowledge goal. Confirm role and tier.
2. Read any draft provided.
3. Load: role index (compressed) + schema index (compressed) + skill registry (existing skills for this role only)
4. Run validation checklist against draft.
5. Report: pass/warning/fail for each check.
6. Fill gaps collaboratively — only ask about what failed.
7. Output complete SKILL.md.
8. Run final validation.
9. "Write this to `skills/[tier-path]/[skill-id]/SKILL.md` and update the registry?"

### 4.2 Karen Mode (Writer Entry)

Karen doesn't know what a skill is. She knows what she wishes the system could do. She might say "I wish you could tell me when a character's voice is drifting" or "is there a way to help me name places that feel right?"

In Karen mode, the Skill Designer:
- Starts from the felt need, not the technical solution
- Translates the need into a skill concept
- Presents the concept in plain English before building anything
- Gets Karen's approval before writing the SKILL.md
- Routes the finished skill to `skills/pending/` for Bill's review

**Entry signal:** A wish, a problem statement, a gap description, a question about possibility. "Can the system…?" "I wish it could…" "Is there a way to…"

**Karen mode flow:**
1. Surface the need. "What are you trying to do that you can't do right now?"
2. Ground it. "When does this come up? What are you working on when it happens?" — This shapes the context fingerprint without Karen knowing that's what's happening.
3. Define the output. "What would you want it to give you — a question, a list, a suggestion, a warning?"
4. Scope it. One skill does one thing well. If Karen describes three needs, identify which is most important: "It sounds like the main thing is X. Want to start there?"
5. Name it. Give Karen a plain-English name. Not a technical ID — a name she'd use to ask for it.
6. Describe the contract. "Here's what this would do: [plain English]. When you use it, it will ask you [X]. It will give you back [Y]. It will save [Z] to your character record."
7. **STOP.** Present concept. "Does that sound right? Anything you'd add or change?"
8. Adjust based on Karen's response.
9. **STOP.** "Ready to build this? Once it's reviewed, it'll be available in your [role] station."
10. Build SKILL.md.
11. Run validation checklist.
12. Write to `skills/pending/[skill-id]/SKILL.md`.
13. Log `SKILL_DRAFTED` audit event with `authored_by: karen`.
14. Tell Karen: "Done. This is waiting for a quick review before it's ready to use. I'll let you know when it's available."

### 4.3 The Review Gate

Every Karen-authored skill lands in `skills/pending/` first. It is not active. The routing skill will not invoke it. It is quarantined — not because Karen's input is untrusted, but because skills affect the write-back contract and the object model. A skill written from a felt need may not have accounted for edge cases that a developer review will catch.

The review gate is not a skepticism about Karen. It is a safety system for Karen's own data.

Bill reviews pending skills using the Skill Designer's "review pending" flow. He may approve as-is, modify, or reject. The skill-installer skill (Tier 1) promotes approved skills from `pending/` to their permanent tier, updates the skill registry, and logs the event.

---

## 5. Skill Designer Conversation Flow

### 5.1 Session Start

The Skill Designer opens by determining mode and purpose:

```
"What are we building today — or is there an existing skill you'd like to look at?"

→ "New skill / I want to build / I need a skill that..."
   Determine Bill or Karen mode from language and vocabulary.

→ "Improve / fix / the [skill name] isn't working / the data says..."
   Load: target SKILL.md + its scorecard + last 5 SKILL_OUTCOME audit events.

→ "Review pending / what's waiting / Karen built something..."
   Load: file list from skills/pending/ only (not full SKILL.md contents yet).
```

### 5.2 New Skill — Bill Mode

1. Confirm: role, tier, deployment target
2. Load role index + schema index + skill registry (existing skills for this role only)
3. Check for responsibility overlap with existing skills in this role
4. If draft provided: validate immediately
5. If no draft: ask targeted questions — what does it do, what does it read, what does it write
6. Fill gaps only — do not re-ask what Bill has already answered
7. Assemble SKILL.md
8. Run final validation
9. Report validation results
10. "Write to `skills/[tier-path]/[skill-id]/SKILL.md`?"
11. If yes: write file + update registry + log `SKILL_INSTALLED`

### 5.3 New Skill — Karen Mode

*(See Section 4.2 above — the full Karen mode flow is defined there.)*

### 5.4 Improve Existing Skill

1. Load target SKILL.md
2. Load its Scorecard record
3. Load last 5 `SKILL_OUTCOME` events for this skill from audit.jsonl
4. Synthesize the performance picture:

   > "This skill has been used [N] times. Karen accepted [X]%, modified [Y]%, and ignored [Z]%. Looking at when she modified it, the [specific section] was most frequently changed — in [N] of [M] uses."

5. Ask: "What specifically isn't working?" Ground improvement in lived experience, not just metrics.
6. If scorecard suggests a specific problem: name it. "The data suggests the midpoint evaluation needs adjustment. Want to look at that?"
7. **STOP.** Agree on what to improve before touching anything.
8. Edit the SKILL.md section by section.
9. Increment version (patch for flow changes, minor for new fields, major for write-back contract changes).
10. Run validation checklist against the updated version.
11. "Save as version [X.Y]?"
12. Log `SKILL_UPDATED` audit event with diff summary.

### 5.5 Review Pending Skills

1. Load file list from `skills/pending/`
2. For each pending skill: skill_id, skill_name, date_created, authored_by
3. "Which would you like to review?"
4. Load selected SKILL.md
5. Run validation checklist
6. Surface all warnings and failures
7. "Approve, modify, or reject?"
8. **Approve:** run skill-installer → write to permanent tier → update registry → remove from pending → log `SKILL_INSTALLED`
9. **Modify:** enter collaborative editing mode → re-validate → re-ask
10. **Reject:** move to `skills/rejected/[skill-id]/SKILL.md` → log `SKILL_REJECTED` → if Karen-authored, generate a plain-English explanation for Karen

---

## 6. The Skill Designer's Own Context Requirements

This is the Skill Designer's SKILL.md-style context declaration. Bottleneck 19.7 in the ShopFloor Storage Spec names the Skill Designer as the most context-hungry operation on the floor. These requirements are the mitigation.

| Resource | Scope | Required | Condition |
|----------|-------|----------|-----------|
| schema_index | system | yes | Always — compressed summary only |
| role_index | system | yes | Always — compressed summary only |
| skill_registry | system | yes | Always — IDs, names, roles, tiers, brief purpose only |
| target_skill_full | skill-specific | conditional | Only when improving or reviewing a specific skill |
| target_scorecard | skill-specific | conditional | Only when improving a specific skill |
| target_audit_events | skill-specific | conditional | Last 5 SKILL_OUTCOME events — only when improving |
| pending_skills_list | system | conditional | File list only — full SKILL.md loaded only on selection |
| manifest | system | yes | Always |
| session-state | system | yes | Always |

**Critical distinction:** The schema_index is not the full `Data Structures/` directory. It is a purpose-built compact file at `.shopfloor/schema-index.json`. Similarly, the role_index is not the full ROLE.md files — it is `.shopfloor/role-index.json`. Both are generated summaries optimized for Skill Designer consumption. The Skill Designer never loads full schema files unless a specific skill requires detailed field-level analysis of a particular schema type.

---

## 7. Output Artifacts

The Skill Designer produces three artifacts for each completed skill operation:

### 7.1 The SKILL.md File

Written to `skills/[tier-path]/[skill-id]/SKILL.md` (active skills) or `skills/pending/[skill-id]/SKILL.md` (Karen-authored skills awaiting review).

This is the canonical output. It must conform to the format defined in Section 3.

### 7.2 The Skill Registry Entry

A JSON record added to or updated in `.shopfloor/skill-registry.json`:

```json
{
  "skillId": "character-creation",
  "skillName": "Character Creation",
  "version": "1.0",
  "tier": 3,
  "role": "dev-editor",
  "deploymentTargets": ["mobile", "desktop"],
  "path": "skills/creative/character-creation/SKILL.md",
  "status": "active",
  "contextFingerprint": {
    "objectModel": [
      "Character_Profile:active",
      "Wound_Profile:linked"
    ],
    "system": ["manifest", "session-state"]
  },
  "authoredBy": "bill",
  "dateCreated": "2026-04-12",
  "dateModified": "2026-04-12"
}
```

The `contextFingerprint` here must exactly mirror the Context Requirements table in the SKILL.md. These two representations of the same data must stay in sync. Any edit to one requires an edit to the other.

### 7.3 The Audit Event

```json
{
  "event": "SKILL_DRAFTED | SKILL_INSTALLED | SKILL_UPDATED | SKILL_REJECTED",
  "timestamp": "[ISO 8601]",
  "skillId": "[skill-id]",
  "skillName": "[skill-name]",
  "tier": 1,
  "role": "[role-id]",
  "authoredBy": "bill | karen | skill-designer",
  "version": "[version string]",
  "notes": "[optional — summary of changes for SKILL_UPDATED events]"
}
```

The Skill Designer logs every action. There are no silent operations. If a skill is drafted and immediately rejected, both events appear in the audit trail.

---

## 8. Validation Protocol

Validation runs before the Skill Designer surfaces any draft. Three outcomes:

| Outcome | Definition | Effect |
|---------|-----------|--------|
| **Pass** | Condition satisfied | No action needed |
| **Warning** | Condition partially satisfied or exceeds a soft limit | Surfaced to the user; does not block output |
| **Fail** | Condition not satisfied | Blocks output; must be resolved before draft is presented |

### Validation Checks

| Check | Outcome if Fails |
|-------|-----------------|
| Frontmatter present and all fields populated | **Fail** |
| `skill_id` is kebab-case | **Fail** |
| `skill_id` is unique in skill registry | **Fail** |
| Identity section present and ≤ 150 words | **Warning** |
| Context Requirements section present and table-parseable | **Fail** |
| Responsibilities section present with explicit "Does NOT" list | **Fail** |
| Conversation Flow present with at least one STOP before write-back | **Fail** |
| Output Format defines both conversational and structured output | **Fail** |
| Structured output schema is valid JSON | **Fail** |
| Write-Back Contract present with field list and "Does NOT touch" list | **Fail** |
| Guardrails section present with at least the four universal rules | **Fail** |
| Context fingerprint within tier budget | **Warning** |
| Deployment target declared | **Fail** |
| No overlapping responsibilities with same-role skills | **Warning** |
| Validation Checklist section present | **Warning** |
| Version history comment block present | **Warning** |

A draft with any **Fail** is not surfaced to the user. The Skill Designer reports the failures and asks collaboratively how to resolve them. A draft with only **Warnings** is surfaced with the warnings explicitly called out. The user decides whether to proceed.

---

## 9. Skill Versioning

### 9.1 Version Schema

Skills use semantic versioning with three tiers:

| Change Type | Version Increment | Example |
|-------------|-------------------|---------|
| Initial release | `1.0` | — |
| Minor — flow, tone, guardrails | `+0.1` | `1.0 → 1.1` |
| Major — write-back contract, context fingerprint, new required fields | `+1.0` | `1.1 → 2.0` |

Breaking changes (major version bumps) require:
1. A `SKILL_VERSION_BREAKING` audit event
2. Skill registry update with new `contextFingerprint`
3. Scorecard reset for the new version — old data is preserved but separated from new metrics by version tag
4. Review of any session-state data that may be affected

### 9.2 Version History

Each SKILL.md carries a version history comment block immediately below the frontmatter:

```markdown
<!-- 
Version History:
1.0 — 2026-04-12 — Initial release (authored: bill)
1.1 — 2026-05-03 — Tightened midpoint analysis (trigger: scorecard, modification_rate=0.62)
2.0 — 2026-07-14 — Added act-three override field to write-back contract (breaking change)
-->
```

This is a human-readable changelog. It supplements the audit trail — the audit trail records events, the version history records intent.

---

## 10. The Feedback Loop

### 10.1 The Data Pipeline

```
Karen uses a skill
    → outcome recorded as SKILL_OUTCOME event (accepted / modified / ignored)
        → optional: Karen tapped feedback (👍 / 👎 / "tell me more")
            → scorecard-updater reads events, updates Scorecard record
                → Skill Designer loads scorecard when "improve" is invoked
                    → targeted improvement based on data
                        → revised skill deployed
                            → next cycle begins
```

This is organizational learning. The system accumulates performance data and uses it to improve, the same way a manager reviews a team member's work and adjusts the process. The intelligence is human-curated in v1. The loop is automatic in v2+.

### 10.2 The Invocation Counter — The Most Important Number

**Total invocations is the primary health signal for any skill.** Acceptance rate, modification rate, and ignored rate are all meaningful — but only once a skill has been used enough times to have a pattern. A skill with 3 invocations and a 100% acceptance rate is not a proven skill. A skill with 0 invocations is a problem, regardless of how well it was designed.

Every Scorecard tracks invocation count at the role level and per-skill. The Skill Designer surfaces this number prominently when reviewing skills. A skill that isn't being used is telling you something:
- It may not be discoverable (routing problem)
- It may not be useful for where Karen is in her project
- It may have been used once and quietly abandoned

Invocation count answers the question a modification rate cannot: *is anyone even on this station?*

### 10.3 Evaluation Modes — The Toggle

Not every skill invocation should interrupt Karen with a feedback request. That would be intolerable. The system has three evaluation modes, configurable at system, role, and skill level (skill overrides role, role overrides system):

| Mode | Behavior |
|------|---------|
| `warranty` | Newly installed skill; prompt Karen after every use until warranty target is reached |
| `active` | Prompt Karen every N uses (default: every 3rd); not invisible, but not constant |
| `passive` | No prompting; track accept/modify/ignore behavior through observation only |

The system default is `active`. Bill can set any role or skill to `passive` when the evaluation friction outweighs the signal value. Karen can toggle this for her own experience via a preference ("stop asking me about this").

The feedback prompt, when it appears, must be **lightweight**. Not a form. Not a survey. A single tap: 👍 / 👎 / "tell me more." Karen answers in under two seconds or skips. Either way, the system records the event.

### 10.4 The Warranty Period

Every newly installed skill enters a **warranty period**. The warranty target is configurable (default: 10 invocations). During warranty:

- Evaluation mode is locked to `warranty` — every use prompts feedback
- The feedback prompt is slightly more expansive than post-warranty: a single optional free-text field appears below the 👍 / 👎 — "What would have made this more useful?" Karen is never required to fill it
- At the end of warranty, the floor reviews the skill's performance automatically:
  - Acceptance rate above quality threshold → skill graduates to the role's default evaluation mode; Bill is notified
  - Acceptance rate below quality threshold → skill is **flagged**, not failed; Bill is notified with the data; Karen is not interrupted; the skill remains active but is marked `under review`

The warranty period produces the most concentrated signal the floor will ever have about a new skill. It is the new skill's probation. It should be designed to be informative, not punishing — Karen's engagement during warranty teaches the floor things passive observation cannot.

After a major version bump (breaking change), the skill re-enters warranty automatically. Old performance data is preserved but separated by version. The new version earns its own record.

### 10.5 v1 — Human-in-the-Loop

1. Skills run. Outcomes are logged as `SKILL_OUTCOME` events in `audit.jsonl`.
2. Optional: Karen's feedback tap logged as `SKILL_FEEDBACK` event (same audit trail).
3. `scorecard-updater` (Tier 1) processes events and updates the Scorecard record.
4. Bill reads scorecards at his discretion or on a schedule.
5. Bill invokes the Skill Designer in "improve existing" mode when data suggests a problem.
6. The Skill Designer loads the scorecard and last 5 outcomes automatically — it does not ask Bill to summarize what he already sees.
7. Improvement is targeted by data, not speculative.

### 10.6 v2+ — Proactive Improvement Suggestions

When the system is given the capability to surface suggestions at session start:

- If a skill's modification rate exceeds the configured threshold (default: 40%, configurable in `system-manifest.json` under `quality_control.modification_threshold`):

  > "The beat-sheet skill has been modified in 4 of the last 5 uses. The midpoint analysis is most often changed. Want to look at adjusting how it evaluates midpoints?"

- Karen can respond in plain English. The Skill Designer translates this into a targeted edit.

- The threshold is not one-size-fits-all. A high-stakes Tier 2 quality control skill may warrant intervention at 25% modification rate. A Tier 3 creative skill with 50% modification may be working exactly as intended — Karen enriches its output by design.

- Skills in `passive` mode are not eligible for proactive v2+ suggestions. If a skill is passive, it is not being evaluated. You cannot act on data you are not collecting.

### 10.7 The Self-Improvement Architecture

The architecture for self-improvement is in place from v1. What changes between v1 and v2+ is only the trigger:

| Version | Who Initiates | How |
|---------|--------------|-----|
| v1 | Bill or Karen explicitly invokes Skill Designer | Manual, data-informed |
| v2+ | System detects threshold breach | Proactive, data-driven |

No structural change is required between v1 and v2+. The data is already collected. The Skill Designer already reads it. The upgrade is a trigger, not an architecture.

---

## 11. Guardrails for the Skill Designer Itself

The Skill Designer is a meta-tool that can modify the floor. These guardrails prevent it from subverting the floor it is meant to serve.

**11.1 Tier 1 skills are off-limits.**
The Skill Designer cannot modify floor management skills: `session-init`, `orphan-manager`, `routing`, `scorecard-updater`, `schema-migrator`, `backup-restore`, `project-export`, `skill-installer`. These are updated by Bill directly, with an explicit `TIER_1_MODIFIED` audit event. The Skill Designer enforces this by checking tier before loading any target skill for improvement.

**11.2 Karen-authored skills go to pending only.**
This is a hard rule. The Skill Designer never writes a Karen-authored skill directly to an active tier. No exception. No override. If Karen somehow requests "just install it now," the Skill Designer declines and explains why.

**11.3 The Skill Designer cannot delete skills.**
It can set `status: deprecated`. It cannot delete the file. Deleted skills lose audit history. Deprecated skills remain traceable. Future versions can be informed by what was tried and didn't work.

**11.4 The Skill Designer cannot modify the Team Manifest directly.**
The Team Manifest is owned by the `skill-installer` and `routing` skills. The Skill Designer produces a candidate Team Manifest change and presents it to Bill for confirmation. It does not execute the change itself.

**11.5 Every action is logged.**
No silent operations. Drafts, updates, rejections, failed validations — all appear in the audit trail. If the Skill Designer touches a skill and the result is discarded, there is still a record that the attempt was made.

---

## 12. Infrastructure Dependencies

The Skill Designer depends on two infrastructure artifacts that do not exist yet and must be built:

### 12.1 Schema Index (`.shopfloor/schema-index.json`)

A machine-generated summary of all data structure schemas. Maintained by `schema-migrator` (Tier 1). Regenerated whenever a schema template version changes.

```json
{
  "generated": "",
  "schema_version": "1.0",
  "schemas": [
    {
      "type": "Character_Profile",
      "category": "noun",
      "template_version": "2.1",
      "id_format": "CHR-NNN",
      "key_fields": ["characterID", "characterName", "narrativeRole", "woundID"],
      "linked_schemas": ["Relationship_Profile", "Group_Profile", "Wound_Profile", "POV_Profile"],
      "writable_by": ["dev-editor"]
    },
    {
      "type": "Wound_Profile",
      "category": "noun",
      "template_version": "1.0",
      "id_format": "WND-NNN",
      "key_fields": ["woundID", "characterID", "coreWound", "falseBelief"],
      "linked_schemas": ["Character_Profile"],
      "writable_by": ["dev-editor"]
    }
  ]
}
```

The `writable_by` field is new. It records which roles have write access to each schema type. This is enforced by the Skill Designer at validation time — a skill cannot write to a schema type its role doesn't own.

### 12.2 Role Index (`.shopfloor/role-index.json`)

A machine-generated summary of all role definitions. Maintained by `session-init` (Tier 1). Regenerated when the Team Manifest changes.

```json
{
  "generated": "",
  "roles": [
    {
      "roleID": "dev-editor",
      "roleName": "Developmental Editor",
      "responsibilities": [
        "character arc analysis",
        "emotional wound profiling",
        "beat sheet generation",
        "scene development support"
      ],
      "tier1Skills": [],
      "tier2Skills": ["character-arc-checker", "conformance-reporter"],
      "tier3Skills": ["character-creation", "wound-intake", "beat-sheet", "scene-development"],
      "writableSchemas": ["Character_Profile", "Wound_Profile", "Scene_Container", "Arc_Beat_Sheet"],
      "fallbackRole": true
    }
  ]
}
```

Both index files are the critical efficiency mechanism for the Skill Designer. The entire role and schema model is available as a compact read, not a full directory scan. The Skill Designer must not operate without them.

---

## 13. New Audit Event Types

The following audit event types are introduced by this specification. They must be added to the ShopFloor Storage Spec audit trail schema (Section 7):

| Event | Trigger |
|-------|---------|
| `SKILL_DRAFTED` | A new SKILL.md has been created and written to `pending/` |
| `SKILL_INSTALLED` | A skill has been promoted to an active tier by skill-installer |
| `SKILL_UPDATED` | An existing skill has been modified and saved with a new version |
| `SKILL_REJECTED` | A pending skill has been rejected and moved to `skills/rejected/` |
| `SKILL_DEPRECATED` | A skill's status has been set to `deprecated` |
| `SKILL_VERSION_BREAKING` | A major version bump has changed the write-back contract |
| `SKILL_FEEDBACK` | Karen tapped 👍 / 👎 / "tell me more" on a skill output (evaluation mode: warranty or active) |
| `SKILL_WARRANTY_COMPLETE` | A skill has completed its warranty period; system evaluated graduation vs. flag |
| `TIER_1_MODIFIED` | A Tier 1 floor management skill has been modified (Bill only) |

---

## 14. Open Questions

| # | Question | Priority |
|---|----------|----------|
| 1 | What is the exact token budget for `schema-index.json` and `role-index.json`? Needs empirical measurement after first skills are built — estimated budgets in Section 6 are targets, not guarantees. | High |
| 2 | Can the Skill Designer run on mobile at all, or is it desktop-only in v1? The context footprint of the Skill Designer's own operation (schema index + role index + skill registry + target skill + target scorecard) is likely to strain mobile context limits. | Medium |
| 3 | What does "Karen approves a skill concept" look like in the UI — a confirmation card, a plain-text description she edits, a preview? The conversational flow is specced; the UI surface is not. | Medium |
| 4 | How does the Skill Designer handle a request to build a skill that closely resembles one that already exists? Detect overlap and redirect to "improve existing" rather than creating a near-duplicate. | Medium |
| 5 | Should pending skills expire — auto-reject if not reviewed within N days? Risk of Karen losing work she was excited about. But an unreviewed skills queue is a dead queue. | Low |
| 6 | The `writable_by` field on schema types (Section 12.1) implies a permissions system. What happens if a skill claims write access to a schema type its role doesn't own — is this a hard block or a warning that Bill overrides? | Medium |
| 7 | Version history is in a comment block in the SKILL.md. Should it also be in the skill registry JSON? Duplication, but makes the registry self-contained for tooling. | Low |

---

## 15. Next Steps

### Before Writing Any Skill

- [ ] Generate `.shopfloor/schema-index.json` from existing data structures
- [ ] Generate `.shopfloor/role-index.json` from Team Manifest
- [ ] Add new audit event types (Section 13) to ShopFloor Storage Spec audit trail section (Section 7)
- [ ] Add `writable_by` field to data structure schema templates

### First Skills (Proof of Concept)

- [ ] Write `character-creation/SKILL.md` (Tier 3, dev-editor) — stress-tests context fingerprint design and Karen-mode flow
- [ ] Write `wound-intake/SKILL.md` (Tier 3, dev-editor) — stress-tests linked schema loading and write-back across two schemas
- [ ] Review both against this spec's validation checklist — the checklist is itself being stress-tested

### Skill Designer Itself

- [ ] Build `skill-designer/SKILL.md` using this specification as the design brief — the Skill Designer is its own first customer
- [ ] Validate the Skill Designer's SKILL.md against its own validation checklist — it must pass

### ShopFloor Spec Updates

- [ ] Add schema-index.json and role-index.json to Section 4.2 (The System Root) directory tree
- [ ] Add new audit event types to Section 7 audit trail schema
- [ ] Resolve Open Question 6 (writable_by permissions model)

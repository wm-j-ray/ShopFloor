---
skill_id: halt-monitor
skill_name: Halt Monitor
version: "1.0"
tier: 1
role: foreman
deployment_targets:
  - mobile
  - desktop
requires_ai: false
status: draft
date_created: "2026-04-15"
date_modified: "2026-04-15"
authored_by: bill
inputs:
  - resource: platform.halt
    scope: product-root
    required: false
  - resource: session-state
    scope: system
    required: true
outputs:
  - resource: session-state
    action: update
  - resource: audit
    action: append
---

<!-- Version history
  1.0 (2026-04-15) — Initial draft. Bill Ray + Claude Sonnet 4.6.
                     Informed by ShopFloor Platform Spec v1.0, §9.1.
-->

---

## 1. Identity

Halt Monitor checks for the `platform.halt` emergency signal at the product root before any other skill runs. If the signal is present, it overrides the product tier to 0, blocks all AI execution for the session, logs the halt event, and surfaces an indicator to Bill. If absent, it passes silently.

**Belongs to:** Foreman
**When it runs:** First step of session-init — before any other Foreman skill.
**Karen's experience:** If halted, her experience degrades silently to Tier 0. She can still read, write, and organize content. She is not told why.

---

## 2. Purpose

Bill needs an emergency brake. One that works from an iPhone at midnight without opening a terminal. Creating a file named `platform.halt` is enough — this skill detects it and shuts down AI execution immediately on the next session init. No configuration edits. No Claude Code. No explanation to Karen required.

---

## 3. Context Requirements

| Resource | Scope | Required | Notes |
|----------|-------|----------|-------|
| `platform.halt` | product-root | no | Checked for existence only; contents ignored |
| `session-state.json` | system | yes | Written to record halt status if detected |
| `audit.jsonl` | system | yes | Appended to when halt is detected or restored |

**Estimated context load:** ~100 tokens. A file existence check and a small write. Well within Tier 1 budget.

**Product root vs. project root:** `platform.halt` lives at the product root — the folder that *contains* project folders (e.g., `StoryEngine/`). This is one level above `.shopfloor/`. The skill resolves the product root by walking up one level from the project root.

---

## 4. Responsibilities

This skill:
- Checks for the existence of `platform.halt` at the product root
- If present: sets `session-state.productTierOverride = 0`, logs `HALT_DETECTED` to audit, surfaces one-line indicator to Bill, exits session-init immediately
- If absent and prior session was halted: logs `HALT_CLEARED` to audit (one-time, only if clearing)
- If absent and no prior halt: passes silently with no output

This skill does NOT:
- Read or interpret the contents of `platform.halt` (existence is sufficient)
- Delete `platform.halt` (only Bill deletes it)
- Inform Karen that halt mode is active
- Run any other skill or trigger any other action
- Generate any output if halt is absent and no prior halt to clear

---

## 5. Execution Flow

```
1. RESOLVE PRODUCT ROOT
   Determine the product root: parent directory of the current project folder.
   If product root cannot be determined: log PLATFORM_ERROR and continue
   (assume no halt — do not block on a path resolution failure).

2. CHECK FOR platform.halt
   Check whether a file named 'platform.halt' exists at the product root.

3a. IF platform.halt EXISTS:
     Set session-state.productTierOverride = 0.
     Log HALT_DETECTED to audit.jsonl:
       { "event": "HALT_DETECTED", "timestamp": "...", "session_id": "...",
         "detected_at": "[absolute path to platform.halt]" }
     Output to Bill (one line):
       "HALT ACTIVE — platform.halt detected at [path]. AI execution blocked for this session. Delete the file to restore."
     EXIT session-init. No further skills run.

3b. IF platform.halt ABSENT and prior_halt_active (read from session-state):
     Clear session-state.productTierOverride.
     Log HALT_CLEARED to audit.jsonl:
       { "event": "HALT_CLEARED", "timestamp": "...", "session_id": "..." }
     Output to Bill (one line):
       "HALT CLEARED — resuming normal operation."
     Continue session-init.

3c. IF platform.halt ABSENT and no prior halt:
     Pass silently. No output. Continue session-init.
```

---

## 6. Output Format

**Halt detected:**
```
HALT ACTIVE — platform.halt detected at /Users/karen/StoryEngine/platform.halt. AI execution blocked for this session. Delete the file to restore.
```

**Halt cleared:**
```
HALT CLEARED — resuming normal operation.
```

**No halt:** *(no output)*

---

## 7. Object Model Writes

| Write | Target | Condition |
|-------|--------|-----------|
| `productTierOverride = 0` | `session-state.json` | Halt detected |
| Clear `productTierOverride` | `session-state.json` | Halt cleared |
| `HALT_DETECTED` event | `audit.jsonl` | Halt detected |
| `HALT_CLEARED` event | `audit.jsonl` | Halt cleared (one-time, on first clear) |

---

## 8. Quality Control

**Evaluation mode:** Warranty (first 10 runs, then passive — this skill is simple and critical; aggressive evaluation is not warranted after warranty).

**What Bill watches for during warranty:**
- False negative: `platform.halt` exists but skill does not block execution
- False positive: skill blocks execution when `platform.halt` is absent
- Karen-visible output: Bill indicator must never surface to Karen

**Automatic failure trigger:** Any AI skill execution occurring in a session where `HALT_DETECTED` was logged. This is an unconditional critical fault.

---

## 9. Notes

**`platform.halt` content is irrelevant.** Any file with this exact name at the product root activates halt mode. An empty file works. A file with notes works. The name is the signal.

**Session-init termination:** When halt-monitor exits with halt active, the entire session-init sequence stops. No other Foreman skills run. No vertical roles activate. The audit trail remains writable — Tier 0 audit-passive operations continue.

**Relationship to session-init:** halt-monitor is step 1 of session-init and the only Foreman skill that can abort the entire sequence on a non-error condition.

---
skill_id: session-init
skill_name: Session Init
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
  - resource: VERTICAL.md
    scope: project-root
    required: true
  - resource: manifest
    scope: system
    required: false
  - resource: session-state
    scope: system
    required: false
  - resource: transactions-directory
    scope: system
    required: false
outputs:
  - resource: session-state
    action: create-or-update
  - resource: audit
    action: append
---

<!-- Version history
  1.0 (2026-04-15) — Initial draft. Bill Ray + Claude Sonnet 4.6.
                     Informed by ShopFloor Platform Spec v1.0, §3, §8, §9, §11, §20, §21.
-->

---

## 1. Identity

Session Init is the Foreman's startup sequence — the ordered set of platform checks that run at the beginning of every session, before any vertical role activates. It runs the other Foreman Tier 1 skills in the correct order, verifies platform state is sound, loads session context, and hands control to the vertical's coordinator role. If anything fails, it reports and stops. If everything passes, Karen's session proceeds normally.

**Belongs to:** Foreman
**When it runs:** Automatically, at the start of every session. Before any vertical role, before any production skill.
**Karen's experience:** None. This is infrastructure. On a healthy platform, session-init completes in the background before Karen sees anything.

---

## 2. Purpose

Every Karen session must start from a verified, consistent platform state. Session Init is the guarantee that this is true. It runs five checks in sequence: emergency halt, transaction recovery, vertical validation, index currency, and manifest presence. Any Fail-level error stops the sequence and reports to Bill. On success, it assembles the active role's station and hands off — and Karen's session begins.

---

## 3. Context Requirements

Session Init loads resources incrementally as each step completes. Early steps need almost nothing; later steps need more.

| Resource | Scope | Required | Notes |
|----------|-------|----------|-------|
| `platform.halt` | product-root | no | Existence check only; halt-monitor handles |
| `VERTICAL.md` | project-root | yes | Needed by vertical-registration (step 3) |
| `global-registry.json` | global | yes | Needed by vertical-registration (step 3) |
| `.shopfloor/transactions/` | system | no | Scanned by transaction-manager (step 2) |
| `manifest.json` | system | no | Checked for existence in step 5; triggers rebuild if missing |
| `session-state.json` | system | no | Created if absent; populated in step 6 |
| Context indexes (per active skill declaration) | system | no | Loaded in step 7 based on active skill's contextFingerprint |
| `audit.jsonl` | system | yes | Appended to throughout |

**Estimated context load:** ~1–4K tokens. Varies by step; context is loaded lazily.

---

## 4. Responsibilities

This skill:
- Runs halt-monitor (step 1): checks for platform.halt; aborts if found
- Runs transaction-manager (step 2): recovers any interrupted write sequences
- Runs vertical-registration (step 3): validates VERTICAL.md; blocks session on Fail
- Runs context-index-generator (step 4): regenerates stale indexes if needed
- Checks for manifest.json (step 5): runs rebuild if missing
- Loads or creates session-state (step 6): populates with current session context
- Assembles the active role's context station (step 7): loads indexes declared in contextFingerprint
- Hands control to the vertical coordinator (step 8)
- Logs SESSION_STARTED to audit when all steps pass
- Reports a structured summary to Bill on any failure

This skill does NOT:
- Run production skills (Tier 2 or Tier 3)
- Route Karen's conversation (that is the vertical coordinator's job — StoryEngine's Managing Editor)
- Modify Karen's content files
- Create entity IDs or object model records
- Run if halt-monitor returns halt active (session-init exits immediately in that case)

---

## 5. Execution Flow

```
1. RUN HALT-MONITOR
   Invoke halt-monitor skill.
   If platform.halt present: halt-monitor reports to Bill. EXIT session-init.
   If clear: continue.

2. RUN TRANSACTION-MANAGER
   Invoke transaction-manager skill.
   Recovers any pending transactions from prior sessions.
   If recovery fails for any transaction: report to Bill, continue (do not block).

3. RUN VERTICAL-REGISTRATION
   Invoke vertical-registration skill.
   If any Fail-level error: report to Bill. EXIT session-init.
     (Bill sees the error taxonomy output from vertical-registration directly.)
   If warnings only: warnings are reported; continue.
   If pass: continue.

4. RUN CONTEXT-INDEX-GENERATOR
   Invoke context-index-generator skill.
   Regenerates stale or missing indexes.
   If index generation fails for any index: log error, report to Bill, continue.
     (A stale index is better than blocking a session; report and proceed.)

5. CHECK MANIFEST
   Check for manifest.json at .shopfloor/manifest.json.
   If missing: invoke rebuild skill. Wait for completion.
     Rebuild reports its own output to Bill.
   If present: continue.

6. LOAD OR CREATE SESSION STATE
   Check for .shopfloor/session-state.json.
   If missing: create with platform defaults:
     { "schemaVersion": "1.0", "sessionId": "[next SES-NNNN]",
       "timestamp": "[ISO 8601 now]", "activeVertical": "[vertical_id]",
       "activeRole": null, "state": {} }
   If present: read. Update "sessionId" and "timestamp" for this session.
   Read the vertical coordinator's Project record (if any active project exists):
     Populate state.active_project_id, state.pipeline_state, state.active_role,
     state.swain_slots_filled, state.pending_disambiguation = false.
   Write updated session-state.json.

7. ASSEMBLE ROLE STATION
   Identify the active role:
     If session-state.state.active_role is set: use it.
     Else: use the vertical coordinator role (e.g., "managing-editor" for StoryEngine).
   Read the active role's skill's contextFingerprint (from skill-registry).
   Load each declared index into the session context.
   The station is now assembled. The active role's skill can execute.

8. LOG AND HAND OFF
   Log SESSION_STARTED to audit.jsonl:
     { "event": "SESSION_STARTED", "timestamp": "...", "session_id": "...",
       "vertical": "[vertical_id]", "active_role": "[role_id]",
       "steps_completed": 7, "indexes_loaded": [list] }
   Hand control to the vertical coordinator.
   (For StoryEngine: the Managing Editor's routing skill activates.)
```

---

## 6. Output Format

**Healthy session (no issues):** *(no output — Karen's session begins)*

**Halt active:** *(halt-monitor output only — see halt-monitor §6)*

**Vertical registration failure:**
*(vertical-registration error output — see vertical-registration §6)*
```
Session blocked. Fix VERTICAL.md errors above and restart.
```

**Rebuild triggered:**
```
manifest.json missing — running rebuild...
[rebuild output]
Session continuing after rebuild.
```

**Partial degradation (index or transaction failure):**
```
[WARNING] Index 'role-index' regeneration failed — [reason]. Session continues with stale index.
```

---

## 7. Object Model Writes

Session Init's own writes are minimal — it orchestrates other skills that do the writing.

| Write | Target | Condition |
|-------|--------|-----------|
| Session state | `session-state.json` | Every session (create or update) |
| `SESSION_STARTED` event | `audit.jsonl` | Every successful session |

All other writes (registry, manifest, indexes, transaction recovery) are performed by the sub-skills session-init invokes.

---

## 8. Quality Control

**Evaluation mode:** Warranty (first 10 runs), then passive. Session Init is the most critical platform path — it must be correct. Active evaluation after warranty would add friction to every session start for no benefit.

**What Bill watches for during warranty:**
- Sub-skill not invoked in the correct order (halt before transaction before registration before indexes)
- Session continuing after a Fail-level registration error
- Session state not populated (null active_role when a project is active)
- Context station not assembled (indexes declared in contextFingerprint not loaded before handoff)
- SESSION_STARTED logged before all steps completed

**Critical invariant:** If vertical-registration returned any Fail, session-init must not reach step 6 or 7. The session is dead. Report and stop.

---

## 9. Notes

**Session Init is the one place the full platform startup sequence is defined.** Changes to the startup order must be reflected here first, then in the individual sub-skill SKILL.md notes. This file is the authoritative sequence.

**Startup sequence rationale:**
1. halt-monitor first — emergency brake must take priority over everything
2. transaction-manager second — recover data consistency before validating the vertical (a pending transaction might affect what vertical-registration reads)
3. vertical-registration third — validate the vertical contract before doing anything that depends on it
4. context-index-generator fourth — indexes must be current before role stations are assembled
5. manifest check fifth — if the manifest is missing, rebuild it before reading session state
6. session state sixth — once infrastructure is verified, load/create the session context
7. station assembly seventh — load the specific context this role needs
8. hand off last — only after the platform is verified and context is ready

**Relationship to vertical coordinator:** Session Init ends when it hands to the vertical coordinator. For StoryEngine, that is the Managing Editor's `routing` skill. The Foreman has no opinion about what Karen wants or which StoryEngine role handles it — that is strictly the vertical's domain.

**Session IDs:** `SES-` prefix, padded to 4 digits, incrementing per-project from manifest. If manifest is being rebuilt, use a timestamp-based session ID (`SES-T[unix-millis]`) for this session only; the next session will return to sequential IDs after the rebuild completes.

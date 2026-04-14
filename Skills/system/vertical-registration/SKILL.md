---
skill_id: vertical-registration
skill_name: Vertical Registration
version: "1.0"
tier: 1
role: foreman
deployment_targets:
  - mobile
  - desktop
requires_ai: false
status: draft
date_created: "2026-04-14"
date_modified: "2026-04-14"
authored_by: bill
---

<!-- Version history
  1.0 (2026-04-14) — Initial draft. Bill Ray + Claude Sonnet 4.6.
                     Informed by ShopFloor Platform Spec v1.0, §3–4.
                     Error taxonomy defined in Platform Spec §4 and Roles/foreman/ROLE.md.
-->

---

## 1. Identity

Vertical Registration reads the project's `VERTICAL.md`, validates it against the platform contract, and — if valid — writes the vertical's entry into the global registry and the project's team manifest. It runs at session start, before any production skill fires. If it finds errors, it reports them and blocks the session. If it finds only warnings, it reports them and continues.

**Belongs to:** Foreman
**When it runs:** Automatically, at every session start, before routing or any other skill.
**Karen's experience:** None. This skill is invisible to her. She never knows it ran.

---

## 2. Purpose

Every session must start from a verified platform state. This skill provides that guarantee. A skill that runs against a malformed or unregistered vertical can write corrupt data, use undefined entity prefixes, or load the wrong context indexes. Vertical Registration is the gate that prevents all of that — one deliberate check before anything else executes.

At Tier 0 (no AI): Bill runs this manually as a validation checklist before activating any skills.
At Tier 2 (Hyperdrive): Claude executes it automatically. The result is the same — a validated, registered vertical or a clear error report.

---

## 3. Context Requirements

| Resource | Scope | Required | Notes |
|----------|-------|----------|-------|
| `VERTICAL.md` | project root | yes | The vertical registration contract. If absent, registration fails immediately with `MISSING_REQUIRED_FIELD` |
| `~/.shopfloor/global-registry.json` | global | yes | Created on first run if it does not exist |
| `team-manifest.json` | project | yes | Created on first run if it does not exist. Updated on every successful registration |
| Role paths declared in `VERTICAL.md` | project | yes | Each declared role path is validated to exist on disk |
| Skill paths declared in `VERTICAL.md` | project | yes | Each declared skill path is validated to exist on disk |

**Estimated context load:** ~500–1,000 tokens. VERTICAL.md, registry entries, manifest. Well within Tier 1 budget of 8K tokens.

**Note on first run:** If `~/.shopfloor/global-registry.json` does not exist at the global path, create it as an empty JSON object `{}` before proceeding. Same for `team-manifest.json` at the project level.

---

## 4. Responsibilities

This skill:
- Reads `VERTICAL.md` from the project root
- Validates every required field is present and correctly typed
- Validates `skill_tier` values are within `[1, 2, 3]`
- Validates `product_tier_compatibility` values are within `[0, 1, 2]`
- Checks `vertical_id` against the global registry for duplicates (skip if this vertical is already registered for this project — re-registration is allowed, duplicate across different projects is a Fail)
- Validates all declared role paths exist on disk
- Validates all declared skill paths exist on disk
- Checks entity type prefixes against global registry for cross-vertical conflicts
- Checks per-file extension field names against the platform-reserved field list for conflicts
- Checks for schema path overlap across declared context indexes (Warning only)
- On any Fail: collects all errors, reports them in the standard format, exits without writing to the registry or manifest
- On Warning only: reports warnings, continues to write
- On success: writes the vertical entry to `~/.shopfloor/global-registry.json`
- On success: writes active roles to `team-manifest.json`
- On success: reports one-line confirmation

This skill does NOT:
- Run any production skill or invoke any other role
- Modify `VERTICAL.md` or any file Karen owns
- Make decisions about which roles should be active beyond what `VERTICAL.md` declares
- Block on warnings — warnings are reported and execution continues
- Partially write the registry on a Fail — it is all-or-nothing

---

## 5. Execution Flow

```
1. LOCATE VERTICAL.md
   Look for VERTICAL.md at the project root.
   If not found: report MISSING_REQUIRED_FIELD for VERTICAL.md. EXIT.

2. READ AND PARSE
   Read VERTICAL.md.
   Initialize an errors[] list and a warnings[] list.

3. REQUIRED FIELD VALIDATION
   For each required field, check presence and type.
   Required fields: vertical_id (string), vertical_name (string), version (string),
   entity_types (array), per_file_extensions (array), context_indexes (array),
   roles (array), skills (array).
   For each missing or wrong-typed field: append MISSING_REQUIRED_FIELD to errors[].

4. TIER VALUE VALIDATION
   For each skill declared under `skills`:
     - Check skill_tier ∈ {1, 2, 3}. If not: append INVALID_TIER_VALUE to errors[].
     - Check product_tier_compatibility values ∈ {0, 1, 2}. If not: append INVALID_TIER_VALUE to errors[].

5. DUPLICATE VERTICAL CHECK
   Load ~/.shopfloor/global-registry.json (create if absent).
   If vertical_id already exists in registry AND project path differs from registered path:
     append DUPLICATE_VERTICAL to errors[].
   (Re-registration of the same vertical at the same project path is allowed — treat as update.)

6. PATH EXISTENCE CHECK
   For each role declared in `roles`: check that the declared ROLE.md path exists on disk.
   For each skill declared in `skills`: check that the declared SKILL.md path exists on disk.
   For each missing path: append PATH_NOT_FOUND to errors[].

7. ENTITY PREFIX CONFLICT CHECK
   For each entity type prefix declared in `entity_types`:
     Check against all prefixes in global-registry.json across all other verticals.
     If conflict found: append ENTITY_PREFIX_CONFLICT to errors[].

8. FIELD NAME CONFLICT CHECK
   Load platform-reserved field list (from system-manifest.json under platform.reserved_fields).
   For each field declared in `per_file_extensions`:
     If field name matches a reserved field: append FIELD_NAME_CONFLICT to errors[].

9. SCHEMA PATH OVERLAP CHECK (Warning)
   For each pair of context indexes declared in `context_indexes`:
     If their source_paths overlap: append SCHEMA_PATH_OVERLAP to warnings[].

10. EVALUATE RESULTS
    If errors[] is non-empty:
      Report all errors in standard format (see Output Format, Section 6).
      EXIT without writing to registry or manifest.
    If warnings[] is non-empty:
      Report all warnings in standard format.
      Continue to step 11.

11. WRITE GLOBAL REGISTRY
    Write or update the vertical's entry in ~/.shopfloor/global-registry.json:
      {
        "[vertical_id]": {
          "vertical_name": "...",
          "version": "...",
          "project_path": "[absolute path to project root]",
          "registered_at": "[ISO 8601 timestamp]",
          "entity_types": [...],
          "roles": [...],
          "skills": [...]
        }
      }

12. WRITE TEAM MANIFEST
    Write or update team-manifest.json at the project root.
    Active roles = all roles declared in VERTICAL.md roles[] where the role path exists on disk.
    Format:
      {
        "vertical_id": "...",
        "updated_at": "[ISO 8601 timestamp]",
        "active_roles": ["role-id-1", "role-id-2", ...]
      }

13. REPORT SUCCESS
    One line: "Registered [vertical_id] v[version] — [N] roles, [M] skills active."
    If warnings were reported in step 10: append "(N warnings — see above)".
```

---

## 6. Output Format

**Success:**
```
Registered storyengine v1.0 — 5 roles, 3 skills active.
```

**Success with warnings:**
```
[SCHEMA_PATH_OVERLAP] — context indexes 'schema-index' and 'role-index' share source path Data Structures/Operations/. Consider splitting source declarations.

Registered storyengine v1.0 — 5 roles, 3 skills active. (1 warning — see above)
```

**Failure:**
```
[MISSING_REQUIRED_FIELD] — entity_types is absent — add entity_types array to VERTICAL.md
[PATH_NOT_FOUND] — Skills/creative/character-arc/SKILL.md — declared skill does not exist on disk
[ENTITY_PREFIX_CONFLICT] — prefix CHR is already registered by vertical 'worldbuilder' — choose a different prefix

Registration failed. 3 errors. No registry writes occurred.
```

One line per error. Format: `[ERROR_CODE] — what failed — what to fix`. No additional explanation beyond that line.

---

## 7. Object Model Writes

| Write | Target | Condition |
|-------|--------|-----------|
| Vertical entry | `~/.shopfloor/global-registry.json` | Success only |
| Active roles | `team-manifest.json` | Success only |

On any Fail, neither file is written. The registry and manifest remain in their prior state.

---

## 8. Quality Control

**Evaluation mode:** Warranty (first 10 runs, then active every 3rd run per system-manifest defaults).

**What Bill watches for during warranty:**
- False negatives: a malformed VERTICAL.md passes registration when it should fail
- False positives: a valid VERTICAL.md is blocked by a spurious error
- Missing errors: a real conflict (prefix, field name) is not caught
- Registry corruption: the written global-registry.json entry is malformed or incomplete

**Automatic failure trigger:** If any production skill fires during a session where Vertical Registration reported errors (i.e., registration was skipped or blocked), that is a critical platform fault. Flag immediately.

---

## 9. Notes

**Re-registration behavior:** Running this skill on a project where the vertical is already registered is safe. It re-validates and updates the registry entry. This allows VERTICAL.md changes to propagate without manual registry edits.

**First-run bootstrap:** If `~/.shopfloor/global-registry.json` or `team-manifest.json` do not exist, this skill creates them. No prior state is required.

**Relationship to session-init:** `vertical-registration` is the first step of `session-init`. It completes before any context indexes are checked or role stations are assembled. If registration fails, session-init stops and no other Foreman skills run.

**Error taxonomy source of truth:** `Roles/foreman/ROLE.md` contains the error taxonomy table. This skill implements it. If the taxonomy changes, update both files.

**platform.halt interaction:** If `platform.halt` exists at the project root, the `halt-monitor` skill handles that — it runs before this skill in the session-init sequence. Vertical Registration never sees a live session with `platform.halt` present; halt-monitor has already exited by then.

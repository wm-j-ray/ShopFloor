---
skill_id: rebuild
skill_name: Rebuild
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
  - resource: file-system
    scope: project-root
    required: true
  - resource: per-file-metadata
    scope: all
    required: true
  - resource: object-model
    scope: all
    required: false
  - resource: VERTICAL.md
    scope: project-root
    required: true
  - resource: skills-directory
    scope: project-root
    required: true
outputs:
  - resource: manifest
    action: create-or-update
  - resource: team-manifest
    action: create-or-update
  - resource: context-indexes
    action: create-or-update
  - resource: skill-registry
    action: create-or-update
  - resource: audit
    action: append
---

<!-- Version history
  1.0 (2026-04-15) — Initial draft. Bill Ray + Claude Sonnet 4.6.
                     Informed by ShopFloor Platform Spec v1.0, §21 (Rebuild Protocol).
-->

---

## 1. Identity

Rebuild reconstructs the platform's derived infrastructure from ground truth when it is missing or corrupt. It rebuilds the file registry, object model registry, team manifest, context indexes, and skill registry — all from the files that actually exist on disk, not from any cached state. It runs automatically when `manifest.json` is missing at session init, or explicitly when Bill invokes it.

**Belongs to:** Foreman
**When it runs:** Automatically when manifest.json is missing at session init; explicitly on Bill's command.
**Karen's experience:** None. Silent operation. Takes effect at the next session-init pass.

---

## 2. Purpose

Platform infrastructure can be lost — iCloud sync conflicts, accidental deletion, migration between devices. Because every derived cache is built from the filesystem and per-file metadata (the ground truth), anything lost can be recovered. Rebuild is the recovery operation. It is also a correctness tool: when something feels wrong about the platform state, rebuild forces the platform back into consistency with what actually exists.

---

## 3. Context Requirements

| Resource | Scope | Required | Notes |
|----------|-------|----------|-------|
| File system | project-root | yes | Walk of all files in the project folder |
| `files/[UUID].json` records | all | yes | Per-file metadata — UUID assignments and file tracking |
| `.shopfloor/object-model/` | all | no | Object model records — read to rebuild objectModelRegistry |
| `VERTICAL.md` | project-root | yes | Needed to rebuild team-manifest and context indexes |
| `Skills/` directory | project-root | yes | Walked to rebuild skill-registry from SKILL.md frontmatter |
| `audit.jsonl` | system | yes | Appended to with PLATFORM_REBUILT event |

**Estimated context load:** ~3–6K tokens. Walks multiple directories and reads many small files. May approach the Tier 1 ceiling on large projects. If context would exceed 8K, rebuild processes in passes: manifest first, then indexes, then skill-registry.

---

## 4. Responsibilities

This skill:
- Walks the project file system and rebuilds `manifest.fileRegistry` from all `files/[UUID].json` records
- Walks `.shopfloor/object-model/` and rebuilds `manifest.objectModelRegistry` from entity records
- Cross-references both registries to populate `manifest.orphanRegistry`
- Rewrites `team-manifest.json` from `VERTICAL.md` declarations
- Regenerates all declared context indexes from source (same logic as context-index-generator)
- Rebuilds `skill-registry.json` from SKILL.md frontmatter across `Skills/`
- Logs `PLATFORM_REBUILT` to audit with counts
- Reports a structured summary to Bill

This skill does NOT:
- Delete or overwrite Karen's content files
- Delete object model records (they are level 3 — authoritative state, not derivable)
- Delete `audit.jsonl` (append-only; irreplaceable)
- Attempt to reconstruct `global-registry.json` (requires cross-project knowledge — manual trigger via vertical-registration)
- Run if halt-monitor found `platform.halt` active (session-init would have exited already)

---

## 5. Execution Flow

```
1. ANNOUNCE START
   Output to Bill: "Rebuild starting — reconstructing platform from ground truth..."

2. REBUILD FILE REGISTRY
   Walk all files and directories in the project folder.
   For each file: check whether a corresponding `files/[UUID].json` exists.
     - Found: read UUID, filename, relativePath, dateModified. Add to fileRegistry.
     - Not found: the file is untracked. Log as new discovery (do not create UUID — that
       is vertical-registration's job, not rebuild's). Record in an "untracked_files" list.
   Write fileRegistry section of manifest.json.

3. REBUILD OBJECT MODEL REGISTRY
   Walk .shopfloor/object-model/ (and .shopfloor/storyengine/object-model/ if present).
   For each .json file: read entityId, entityType, schemaVersion, dateCreated, dateModified.
   Build objectModelRegistry array.
   Write objectModelRegistry section of manifest.json.

4. CROSS-REFERENCE AND ORPHAN DETECTION
   For each object model record: check whether its linked file UUID is in fileRegistry.
   If UUID not found in fileRegistry: mark entity as orphaned.
   Populate manifest.orphanRegistry.
   Write orphanRegistry section of manifest.json.

5. REBUILD TEAM MANIFEST
   Read VERTICAL.md roles[] array.
   For each role: check that the declared ROLE.md path exists on disk.
   Write team-manifest.json:
     { "vertical_id": "...", "updated_at": "...", "active_roles": [...] }

6. REGENERATE CONTEXT INDEXES
   Execute the same logic as context-index-generator (§5 of that skill's flow).
   Force regeneration regardless of staleness (rebuild = authoritative refresh).

7. REBUILD SKILL REGISTRY
   Walk Skills/ directory recursively.
   For each SKILL.md found: read frontmatter.
   Extract: skill_id, skill_name, version, tier, role, requires_ai, status, deployment_targets,
            contextFingerprint (inputs[] and outputs[]), date_modified.
   Build skill-registry.json:
     {
       "generated": "[ISO 8601 now]",
       "schema_version": "1.0",
       "platform_skills": [...],
       "vertical_skills": { "[vertical_id]": [...] }
     }

8. LOG REBUILD
   Append PLATFORM_REBUILT to audit.jsonl:
     { "event": "PLATFORM_REBUILT", "timestamp": "...", "session_id": "...",
       "files_registered": N, "objects_registered": M, "orphans_found": K,
       "indexes_regenerated": J, "skills_registered": L,
       "untracked_files": [optional list if any found],
       "trigger": "missing_manifest | explicit" }

9. REPORT TO BILL
   Multi-line summary (see Output Format, §6).
```

---

## 6. Output Format

```
Rebuild starting — reconstructing platform from ground truth...

  File registry:          47 files registered
  Object model registry:  31 entities registered
  Orphans detected:       0
  Team manifest:          5 roles active
  Context indexes:        2 regenerated (schema-index, role-index)
  Skill registry:         7 skills registered

Rebuild complete. Platform state restored. See audit trail for full detail.
```

**If untracked files found:**
```
  Untracked files: 3 files have no UUID record — run vertical-registration to assign them.
```

---

## 7. Object Model Writes

| Write | Target | Condition |
|-------|--------|-----------|
| `fileRegistry` | `manifest.json` | Always (rebuild) |
| `objectModelRegistry` | `manifest.json` | Always (rebuild) |
| `orphanRegistry` | `manifest.json` | Always (rebuild) |
| Active roles | `team-manifest.json` | Always (rebuild) |
| Index files | `.shopfloor/[index output paths]` | Always (force regeneration) |
| Skill entries | `skill-registry.json` | Always (rebuild) |
| `PLATFORM_REBUILT` event | `audit.jsonl` | Always |

No partial writes. If any step fails, log the failure, report to Bill, and continue with remaining steps. A partial rebuild is better than none.

---

## 8. Quality Control

**Evaluation mode:** Warranty (first 10 runs), then passive. Rebuild is an infrequent recovery operation; it should not interrupt normal sessions with evaluation prompts.

**What Bill watches for during warranty:**
- File registry count inconsistency (rebuild reports N files but fewer are actually indexed)
- Orphan false negatives (entities whose linked files no longer exist but are not flagged)
- Stale indexes after rebuild (indexes should always be fresh after rebuild, never stale)
- Missing skills in registry (a SKILL.md on disk not appearing in skill-registry)

**Rebuild is idempotent.** Running it twice produces the same result as running it once. Safe to re-run if the first run was interrupted.

---

## 9. Notes

**What cannot be rebuilt (Platform Spec §21.3):**
- `audit.jsonl` — append-only log, no source. Never overwrite it. If missing, create an empty one and log `AUDIT_LOG_MISSING`.
- Object model records themselves — they are level 3 (authoritative state). Rebuild reads them; it does not recreate them from any source.
- `global-registry.json` — requires cross-project knowledge. Re-run `vertical-registration` in each project manually.
- Karen's content files — not the platform's responsibility.

**Trigger: missing manifest.** Session-init checks for `manifest.json` before transaction-manager runs. If missing, rebuild fires immediately. This is the most common automatic trigger — a new device opening the project for the first time.

**Untracked files:** Files that exist in the project but have no `files/[UUID].json` record are reported but not automatically registered. UUID assignment is a vertical-registration responsibility. Rebuild reports these as informational; they do not block the rebuild.

**Context budget concern:** On very large projects, walking all files and records may approach the Tier 1 8K token limit. If this occurs in practice, split rebuild into two explicit invocations: `rebuild --manifest` and `rebuild --indexes`. Track this as a future optimization if encountered during warranty.

---
skill_id: context-index-generator
skill_name: Context Index Generator
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
  - resource: VERTICAL.md
    scope: project-root
    required: true
  - resource: index-sources
    scope: all
    required: true
outputs:
  - resource: context-indexes
    action: create-or-update
  - resource: audit
    action: append
---

<!-- Version history
  1.0 (2026-04-15) — Initial draft. Bill Ray + Claude Sonnet 4.6.
                     Informed by ShopFloor Platform Spec v1.0, §8 (Context Indexing).
-->

---

## 1. Identity

Context Index Generator builds and maintains the compressed index files that skills load at runtime. It reads the indexes declared in `VERTICAL.md`, checks whether each is current, and regenerates only those whose source files have changed since last generation. When all indexes are current, it runs silently.

**Belongs to:** Foreman
**When it runs:** Step 4 of session-init — after vertical-registration confirms the vertical is valid.
**Karen's experience:** None. Indexes are platform infrastructure. Karen never sees them.

---

## 2. Purpose

Skills need fast access to structured information — schema names, field lists, role capabilities — without loading dozens of full documentation files. The context indexes provide that: compact, current summaries that fit within a skill's context budget. This skill keeps those summaries accurate and fresh without regenerating them on every session start (which would make the Foreman a bottleneck). Lazy regeneration means zero overhead when nothing has changed.

---

## 3. Context Requirements

| Resource | Scope | Required | Notes |
|----------|-------|----------|-------|
| `VERTICAL.md` | project-root | yes | Declares which indexes to generate, their sources, and output paths |
| Source directories | all | yes | Each directory declared in `indexes[].sources` in VERTICAL.md |
| Existing index files | system | no | Read to check `generatedAt` timestamp for staleness detection |
| `audit.jsonl` | system | yes | Appended to when indexes are regenerated |

**Estimated context load:** ~500–3K tokens depending on source file count and index count. For StoryEngine's two declared indexes (schema-index, role-index), well within Tier 1 budget.

---

## 4. Responsibilities

This skill:
- Reads the `indexes` array from the registered vertical's `VERTICAL.md`
- For each declared index: checks whether the existing index file is current
- Staleness check: compare the `generatedAt` timestamp in the existing index against the `dateModified` of all source files
- If stale or missing: regenerates the index from source
- If current: skips without any output
- Writes generated index files in the platform envelope format
- Logs `INDEX_GENERATED` to audit for each index regenerated
- Reports one line per regenerated index; nothing when all current

This skill does NOT:
- Generate indexes not declared in `VERTICAL.md`
- Load or interpret the semantic content of schema templates (extracts metadata only)
- Run production skills or access vertical object model records
- Delete existing index files (replaces them only when stale)
- Block session-init on a stale index — the index is regenerated in place before proceeding

---

## 5. Execution Flow

```
1. READ INDEX DECLARATIONS
   Read VERTICAL.md indexes[] array.
   If no indexes declared: EXIT silently.

2. FOR EACH DECLARED INDEX:

   a. STALENESS CHECK
      Resolve the declared output path (e.g., .shopfloor/schema-index.json).
      If output file does not exist: mark as NEEDS_GENERATION.
      If output file exists:
        Read generatedAt timestamp from index file.
        Walk all declared source paths; collect dateModified of each source file.
        If any source file dateModified > generatedAt: mark as NEEDS_GENERATION.
        Otherwise: mark as CURRENT. Skip to next index.

   b. GENERATE INDEX
      For each source path declared in indexes[i].sources:
        Walk the directory; collect all .md files.
        For each file: extract compact metadata (see §5.1 below).
      Assemble index file using platform envelope:
        {
          "indexId": "[index id]",
          "vertical": "[vertical_id]",
          "generatedAt": "[ISO 8601 now]",
          "generatedBy": "foreman/context-index-generator",
          "entryCount": N,
          "entries": [...]
        }

   c. WRITE INDEX FILE
      Write to the declared output path.
      If directory does not exist: create it.

   d. LOG GENERATION
      Append INDEX_GENERATED to audit.jsonl:
        { "event": "INDEX_GENERATED", "timestamp": "...", "session_id": "...",
          "indexId": "...", "entryCount": N, "sourceFileCount": M,
          "reason": "missing | stale" }

   e. REPORT TO BILL (one line):
      "INDEX_GENERATED [index_id] — [N] entries from [M] source files ([reason])"

3. SUMMARY
   If one or more indexes were regenerated:
     "[N] index(es) regenerated."
   If all current: (no output)
```

### 5.1 Compact Metadata Extraction

For **schema templates** (source: `Data Structures/` directories):
- Extract from YAML frontmatter: `schema_type`, `category`, `vertical`, `template_version`
- Extract the entity type prefix from VERTICAL.md `entity_types` by matching `name` to file stem
- Extract top-level field names from the markdown body (first column of each `## Section` table)
- Entry format: `{ "id": "Character_Profile", "typePrefix": "CHR", "category": "noun", "vertical": "storyengine", "schemaVersion": "2.1", "fields": ["name", "origin", "appearance", "role", "wound", ...] }`

For **role definitions** (source: `Roles/` directory):
- Extract from ROLE.md body: role ID (kebab-case directory name), role name (first `#` heading), layer (platform/vertical), tier, domain summary (first sentence of Domain section)
- Extract skill lists from the Skills section
- Extract routing triggers from the Routing Triggers section
- Entry format: `{ "id": "acquisitions-editor", "name": "Acquisitions Editor", "layer": "vertical", "tier": 3, "domain": "Raw material evaluation...", "skills": ["starting-lineup"], "routingTriggers": [...] }`

**What is NOT extracted:** Full field descriptions, usage notes, examples, voice guidance, pipeline position text, section body prose. The index is a lookup table — not a reading experience.

---

## 6. Output Format

**Index regenerated:**
```
INDEX_GENERATED schema-index — 49 entries from 49 source files (stale)
INDEX_GENERATED role-index — 6 entries from 6 source files (missing)
2 index(es) regenerated.
```

**All current:** *(no output)*

---

## 7. Object Model Writes

| Write | Target | Condition |
|-------|--------|-----------|
| Index file | `.shopfloor/[output-path]` (declared in VERTICAL.md) | When stale or missing |
| `INDEX_GENERATED` event | `audit.jsonl` | Each index regenerated |

---

## 8. Quality Control

**Evaluation mode:** Warranty (first 10 runs), then passive. Index generation is deterministic and mechanical — active evaluation is not warranted after warranty.

**What Bill watches for during warranty:**
- Incomplete entries: a schema file that exists on disk but is missing from the generated index
- Stale false negative: an index that shows as current when a source file was actually modified
- Stale false positive: an index that regenerates when nothing has changed (adds latency for no reason)
- Malformed index JSON: the output file is not valid JSON or is missing the platform envelope fields

---

## 9. Notes

**Index format is the platform envelope, content is vertical-defined.** If the vertical declares a custom `entrySchema` in its VERTICAL.md index declaration, use that structure for entries. If none declared, use the defaults in §5.1. VERTICAL.md is the authority on what content goes in each index.

**source-based invalidation:** The `invalidatedBy: sources` declaration in VERTICAL.md means "regenerate when any file in the source directories has a modification time newer than the index's `generatedAt`." Other invalidation modes may be defined in future VERTICAL.md versions.

**First run vs. incremental:** On first run (index missing), all source files are processed. On subsequent runs, staleness detection means only changed sources need processing — but the full index is still regenerated from all sources (not patched). This keeps the index consistent and avoids partial-update bugs.

**Relationship to skill-designer:** The Skill Designer (Foreman Tier 3) reads `schema-index` and `role-index`. It declares these in its `contextFingerprint`. Context-index-generator must complete before skill-designer can run in any session.

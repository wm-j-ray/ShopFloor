---
skill_id: transaction-manager
skill_name: Transaction Manager
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
  - resource: transactions-directory
    scope: system
    required: false
  - resource: object-model
    scope: system
    required: false
outputs:
  - resource: transactions-directory
    action: update
  - resource: object-model
    action: update
  - resource: audit
    action: append
---

<!-- Version history
  1.0 (2026-04-15) — Initial draft. Bill Ray + Claude Sonnet 4.6.
                     Informed by ShopFloor Platform Spec v1.0, §20 (Transaction Model).
-->

---

## 1. Identity

Transaction Manager scans for interrupted write sequences from prior sessions and recovers them. A crash or timeout mid-write can leave the system in a partially-written state — an entity record written but the manifest not updated, a cross-reference set but the audit not appended. This skill finds those incomplete transactions and finishes them safely.

**Belongs to:** Foreman
**When it runs:** Step 2 of session-init — immediately after halt-monitor, before vertical-registration.
**Karen's experience:** None. This skill is invisible to her. When there is nothing to recover, it adds zero overhead.

---

## 2. Purpose

Multi-step write sequences cannot be made atomic on a filesystem. A crash at step 3 of 5 leaves the platform inconsistent. Transaction Manager is the recovery mechanism — it reads the pending transaction records that skills write before beginning any write sequence, detects which steps were incomplete, and re-executes them idempotently. When everything is clean, it runs in milliseconds and produces no output.

---

## 3. Context Requirements

| Resource | Scope | Required | Notes |
|----------|-------|----------|-------|
| `.shopfloor/transactions/` | system | no | Directory scanned for pending transaction files. If absent or empty: no action. |
| Object model records | system | no | Read during recovery to determine current state before re-executing |
| `manifest.json` | system | no | Read and potentially updated during recovery |
| `audit.jsonl` | system | yes | Appended to for each recovered transaction |

**Estimated context load:** ~200 tokens baseline; up to ~2K tokens if transactions are pending (reads the transaction files and the affected records). Scales with pending transaction count — practically zero overhead when the system is clean.

---

## 4. Responsibilities

This skill:
- Scans `.shopfloor/transactions/` for files with `"status": "pending"`
- For each pending transaction: reads the operations list and identifies incomplete steps
- Re-executes each incomplete step using idempotent semantics
- Updates the transaction file's operation statuses as recovery proceeds
- Sets the recovered transaction to `"status": "recovered"` on completion
- Moves recovered transactions to `.shopfloor/transactions/committed/`
- Logs `TRANSACTION_RECOVERED` to audit for each transaction recovered
- Reports one line per recovered transaction to Bill

This skill does NOT:
- Delete pending transaction files — it recovers them or leaves them for investigation
- Partially recover — either a transaction is fully recovered or left in its pending state
- Run if `.shopfloor/transactions/` is absent or empty
- Modify Karen's content files
- Interrupt or reorder recoveries — each transaction is recovered in isolation

---

## 5. Execution Flow

```
1. CHECK TRANSACTIONS DIRECTORY
   Look for .shopfloor/transactions/.
   If directory does not exist or is empty: EXIT silently. Zero overhead.

2. SCAN FOR PENDING TRANSACTIONS
   List all .json files in .shopfloor/transactions/ (not in committed/).
   For each file: read and parse.
   Skip files with status != "pending".
   If no pending files found: EXIT silently.

3. FOR EACH PENDING TRANSACTION:

   a. ASSESS OPERATIONS
      Read each operation entry in the "operations" array.
      Identify which have "status": "completed" vs "status": "pending".

   b. FOR EACH INCOMPLETE OPERATION (in sequence order):
      Check current state using source of truth hierarchy (Platform Spec §19):
        - Is the target file in the expected state already?
        - If yes (idempotent re-execution would be a no-op): mark completed, continue.
        - If no: execute the operation.

      Operation types and their idempotent implementations:
        write_object   — read current file if it exists; overwrite only if content differs
                         (same entityID = same record; overwriting with identical content is safe)
        update_xref    — read linking array; add entry only if not already present
        update_manifest — upsert on entityID — overwrite entry if present, insert if absent
        append_audit   — match on (timestamp + sessionId + event) before appending; skip if duplicate

      After each successful operation: update operation status to "completed" in the
      transaction file (write in place).

   c. SET TRANSACTION RECOVERED
      When all operations are completed:
        Update transaction status: "status": "recovered"
        Record "recoveredAt": "[ISO 8601 timestamp]"
        Move file to .shopfloor/transactions/committed/[txn-uuid].json

   d. LOG RECOVERY
      Append TRANSACTION_RECOVERED to audit.jsonl:
        { "event": "TRANSACTION_RECOVERED", "timestamp": "...", "session_id": "...",
          "txnId": "...", "originalSkillId": "...", "operationsRecovered": N }

   e. REPORT TO BILL (one line per transaction):
      "RECOVERED txn-[id] ([skill_id], [N] operations, interrupted [timestamp])"

4. SUMMARY
   If one or more transactions were recovered:
     "[N] transaction(s) recovered. See audit trail for details."
   If none were pending: (no output — step 1 exits early)
```

---

## 6. Output Format

**Transactions recovered:**
```
RECOVERED txn-a3f9c21d (starting-lineup, 3 operations, interrupted 2026-04-14T18:00:00Z)
RECOVERED txn-b7d82e44 (character-creation, 2 operations, interrupted 2026-04-14T17:42:00Z)
2 transaction(s) recovered. See audit trail for details.
```

**Nothing to recover:** *(no output)*

---

## 7. Object Model Writes

| Write | Target | Condition |
|-------|--------|-----------|
| Recovered object records | `.shopfloor/object-model/` | Each incomplete write_object operation |
| Updated cross-references | Object model records | Each incomplete update_xref operation |
| Updated manifest registry | `manifest.json` | Each incomplete update_manifest operation |
| `TRANSACTION_RECOVERED` event | `audit.jsonl` | Each recovered transaction |
| Transaction status update | `.shopfloor/transactions/[txn-uuid].json` | Each recovered transaction |
| Move to committed | `.shopfloor/transactions/committed/` | Each recovered transaction |

All writes use idempotent semantics. Re-executing an already-completed operation produces no change.

---

## 8. Quality Control

**Evaluation mode:** Warranty (first 10 runs), then passive. This skill runs before any production work is possible — aggressive evaluation would delay every session start for no benefit.

**What Bill watches for during warranty:**
- Recovery that corrupts rather than repairs (post-recovery state should match what the interrupted skill intended)
- False recovery: marking a transaction as recovered without completing all operations
- Silent failure: a pending transaction that is skipped rather than recovered
- Audit entries that do not match actual recovery operations

**Recovery failure:** If any operation in a transaction cannot be recovered (e.g., required source data is missing), mark that operation `"status": "unrecoverable"` and leave the transaction as `"status": "partial"` in its current location. Log `TRANSACTION_UNRECOVERABLE` to audit with details. Report to Bill. Continue with other transactions.

---

## 9. Notes

**Idempotency is the invariant.** Every write operation defined in the write-back contract (Platform Spec §3.3) must be idempotent. If a new operation type is added and cannot be made idempotent, it must not appear in a transaction sequence.

**Transaction file atomicity:** The transaction file itself is written as a single file write before any other write begins. On recovery, the file is already present and can be read to determine what was attempted. The transaction file is the source of truth for recovery intent.

**Transaction accumulation:** If many transactions accumulate (unusual but possible after repeated crashes), recovery runs them in order of their `timestamp` field. Ordering by time reduces the risk of recovering a later transaction that depends on an earlier one not yet recovered.

**`.shopfloor/transactions/committed/`:** This directory accumulates committed transaction records. They are safe to delete periodically (they are derived/historical data, not ground truth). During warranty, leave them for inspection.

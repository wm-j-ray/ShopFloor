# Design Session — Roles, Particles, Architecture Refinement
**Date:** April 14, 2026  
**Session type:** Design refinement — roles, particles, product tiers, app architecture  
**Conducted under:** gStack (office-hours context)  
**Rule established this session:** All future work is conducted under gStack. Always.

---

## Critical Rule Going Forward

Every session must be conducted under gStack. Session decisions must be written to Notes/ before closing. Commit and push to GitHub at end of every session. No exceptions.

---

## Role Structure — FINAL (Locked)

The old four-role structure (Developmental Editor, Copy Editor, Continuity Guard, Story Keeper) is replaced with five real-world publishing roles:

| Role | Job in one sentence |
|------|-------------------|
| **Acquisitions Editor** | Develops a particle into a Starting Line-Up |
| **Publisher** | Go / no-go decision, commits resources |
| **Developmental Editor** | Post-greenlight: structure, character, arc, beats — the hard work |
| **Proofreader** | Correctness, consistency, style — last mile before manuscript leaves Karen's hands |
| **Managing Editor** | Floor infrastructure — routing, sessions, skills (invisible to Karen) |

**Why this structure:**
- Maps to real publishing roles Karen already understands
- Clean sequential pipeline: Idea → Pitch → Greenlight → Development → Polish
- No overlapping territory between roles
- Continuity Guard eliminated — too thin, absorbed into Proofreader
- "Story Keeper" replaced with "Managing Editor" — sounds like a real person

**The pipeline:**
```
Particle → Starting Line-Up → Greenlight → Development → Polish
           Acquisitions Ed.    Publisher    Dev. Editor   Proofreader
```

---

## Particle — Fundamental Redesign (Locked)

### Old model (WRONG)
Particle was a standalone JSON record in `.shopfloor/object-model/` containing the captured content. Karen never saw a particle as a file.

### New model (CORRECT)
**A particle is a tag on a file.** Not a separate data structure. Not a JSON record in `object-model/`. Just a flag — `isParticle: true` — in the per-file metadata that ShopFloor already maintains for every file.

The file lives where Karen put it — her inbox notebook, her cybercrime notebook, wherever. ShopFloor doesn't move it, doesn't copy it. It just notes: *this file has been elevated.*

Particle fields live in `.shopfloor/files/[UUID].json` — the per-file metadata record that already exists. Particle enrichment is optional fields added to that record when Karen promotes a file.

```json
{
  "uuid": "8F3A2C1D...",
  "currentFilename": "swatting-nyc.md",
  "relativePath": "Cybercrime/swatting-nyc.md",
  "isParticle": true,
  "particleStatus": "raw",
  "resonanceNote": "",
  "sourceApp": "Safari",
  "linkedEntities": []
}
```

**What this eliminates:**
- The entire `Particle_PRT00001.json` pattern in `object-model/`
- The `PRT` counter in idCounters
- The `Particle` as a separate schema

**"Show me my particles"** = a filtered view. Show all files where `isParticle: true`. A lens on existing files, not a separate data store.

**File protection:** Karen is fully protected when she renames or moves files. The UUID never changes. The per-file metadata record updates `currentFilename` and `relativePath` automatically via the self-healing rename detection system. The particle tag follows the file silently.

**This is NOT a macOS tag.** Nothing to do with Finder colored labels. It's a field in a hidden JSON file Karen never sees.

---

## Particle Status Lifecycle

`raw → considered → developing → placed`

With `shelved` as a lateral exit from any state except `placed`.

- `raw` — captured, not yet engaged with
- `considered` — Karen engaged (resonance note added, or entity pre-assigned at capture)
- `developing` — Karen is actively working this toward a Starting Line-Up
- `placed` — incorporated into an active project
- `shelved` — intentionally set aside, can be retrieved

---

## Capture Flow (Confirmed)

Karen uses iOS Share Sheet → selects ShopFloor → picks a notebook (or defaults to Inbox) → file saved. That's it. No friction.

The Inbox notebook is a first-class concept:
- System-level: `StoryEngine/Inbox/` — catches captures with no project assigned
- Project-level: `[ProjectName]/Inbox/` — catches captures for a specific project

If Karen doesn't want to think about where to put something, it goes to Inbox. She sorts it later.

---

## Product Tier Model (Locked)

Three tiers, one consistent conversational UI throughout:

**Tier 0 — Stash + Readwise (free)**
Fast capture via Share Sheet. Notebooks and documents. Search and resurface. Value on day one, no AI required.

**Tier 1 — Prompt Cookbook (paid, no subscription)**
Same conversational interface. Instead of Claude executing a skill, ShopFloor pre-cooks the prompt and Karen pastes it into whatever AI she has (Claude, ChatGPT, Copilot, Gemini). She pastes the result back. ShopFloor captures and organizes it. Zero API cost. Full workflow value.

**Tier 2 — Hyperdrive (subscription)**
Same UI. Same roles. Same conversations. Claude executes natively. Results come back formatted, filed, managed.

**Key design principle:** The roles are tier-agnostic. The Acquisitions Editor is always the Acquisitions Editor. What changes is the engine underneath — prompt clipboard vs. native Claude. Karen should not feel a mode switch. She should feel a speed and depth difference.

**Trial model:** 30-day full Tier 2 functionality (like Readwise). After trial, gates kick in.

**Gillette model:** ShopFloor = razor handle (one-time purchase). Skill packs = blades (different verticals, different capabilities).

**No forms ever.** Even non-AI mode must feel conversational. Karen churns if she sees forms.

---

## App Architecture (Locked)

**Native iOS/macOS app.** The filesystem is the product. The UI makes it fast, intuitive, and pretty. Notebooks App (Alfons Schmidt) is the reference architecture.

Open Question #1 from ShopFloor Storage Spec is CLOSED: native app, filesystem with UI frontend.

**File I/O is always client-side.** iCloud handles sync. Skills can be developed by Bill, deployed as hidden files, distributed with the app.

**Karen sees:** Notebooks (folders) and documents (files). She can rename, move, create sub-notebooks, organize however she wants. The filesystem prettied up.

**Skills have two implementations:**
- Local mode — runs on device, no AI, always available
- AI mode — calls Claude API, requires connectivity and subscription

---

## Swain Starting Line-Up

The pre-greenlight artifact. Developed by Acquisitions Editor from a particle.

**Five elements:**
1. Focal Character
2. Situation
3. Objective
4. Opponent
5. Threatening Disaster

**Output:** Two sentences
- Statement: [Focal Character] in [Situation] attempts to [Objective].
- Question: But can they achieve [Objective] against [Opponent] before [Threatening Disaster] occurs?

**Starting_Lineup** is a new data structure needed (not yet created). Links to source particle(s). Status: `draft → refined → pitched → greenlit / rejected / shelved`.

---

## Open Questions Resolved This Session

- **#1 Native app vs file system as app** → CLOSED: Native app.
- **#3 Mobile skill runtime** → CLOSED: Native app has full filesystem access on iOS.
- **#4 Object model update trigger** → CLOSED: Explicit skill invocation only.
- **#10 Shared skills across roles** → CLOSED: Continuity Guard eliminated, no more shared ownership issue.

---

## Files That Need Updating (Not Yet Done)

These changes were decided but not yet written to files:
1. Particle.md — needs full rewrite to reflect particle-as-tag model
2. Team_Manifest.md — needs new five-role structure
3. ShopFloor Storage Spec — Section 6.2.1 (particle), Section 13.5 (team manifest), Section 17 (layout), Section 20 (close open questions)
4. Starting_Lineup.md — new schema, doesn't exist yet
5. ROLE.md files — not yet written (next major task)

---

## Next Steps (In Order)

1. Update Particle.md, Team_Manifest.md, ShopFloor Storage Spec *(in progress)*
2. Write five ROLE.md files under gStack
3. Generate schema-index.json and role-index.json
4. Write Starting_Lineup.md schema
5. Write Skills/creative/acquisitions-editor/starting-lineup/SKILL.md — first proof-of-concept
6. Write Skill Designer SKILL.md — the meta-skill

---

## Session Rule Established

**Every session going forward:**
1. Conducted under gStack
2. Decisions written to Notes/ before closing
3. Committed and pushed to GitHub at session end
4. No exceptions

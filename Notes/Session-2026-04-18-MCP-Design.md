# Session Notes — 2026-04-18 — MCP Design Session

## Summary

Office hours session exploring whether MCP (Model Context Protocol) has a place in
ShopFloor's architecture. Outcome: yes, and the platform was already designed
MCP-shaped without knowing it.

## Key Decisions

### 1. ShopFloor is MCP-shaped (locked)

The existing architecture maps cleanly onto MCP primitives:
- Skills → MCP Tools
- Notebooks → MCP Resources
- Managing Editor → Router, exposed as single `storyengine_route` MCP tool
- Vertical/platform seam → MCP server namespacing

"MCP-izing" is a formalization, not a redesign. SKILL.md remains the authoritative
source of truth. MCP tool registration is the machine-readable runtime form on top.

### 2. One entry-point tool per vertical (locked)

**Do NOT register N skills as N tools.** Register one tool per vertical:
`storyengine_route` (params: `{project: string, message: string}`). The Managing
Editor implements the routing logic. Exposing individual skills as peer tools leaks
platform internals and forces contract churn every time a skill is added.

Multi-vertical future: `legalengine_route`, `hoaengine_route` — one tool per
vertical, independent contracts.

### 3. MCP near-term value is Bill's dev loop (locked)

**Primary motivation:** Bill's feedback cycle — exercise skills against real
`.shopfloor/` project state from Claude Desktop without rebuilding the Xcode target.
Current loop: ~5 minutes (Xcode build + navigate). MCP target loop: ~30 seconds.

Karen's Claude Desktop access is a real v2 motivation but not the near-term driver.
**Evidence signal to watch:** if >50% of MCP connections come from Karen, shift
resources to Approach B (Resources/notebook exposure) immediately.

### 4. Phase 1 build spec (Approach A)

New macOS-only Swift target: `App/MCPServer/`
- `main.swift` — stdio loop, JSON-RPC 2.0, MCP protocol version 2025-06-18 (pin it)
- `Tools.swift` — one registered tool: `storyengine_route`
- `RouterBridge.swift` — loads `.shopfloor/` state via `ShopfloorFileActor`, stub router

**Phase 1 stub router is a name mapper only.** Returns which role and skill would
handle the message. No prompt engineering. No Claude invocation. No context formatting.

**Response schema:**
```json
{ "role": "string", "response": "string", "skill_invoked": "string", "error": "string | null" }
```

No-route case: `{ "role": null, "skill_invoked": null, "response": "I couldn't route this message. Try rephrasing.", "error": null }`

**Port:** localhost:9999 (hardcoded Phase 1; port management deferred to Approach B)
**Transport:** stdio only. No HTTP, no SSE, no remote transport in Phase 1.

**Ship criteria:** Bill opens Claude Desktop, types "what particles are in my current
project," gets a routed Managing Editor response backed by real `.shopfloor/` JSON.

### 5. iOS MCP is in-process only (settled)

iOS CAN support MCP — local HTTP server within the app's process, foreground only.
macOS runs a persistent service. Not "impossible on iOS," just constrained.
iOS MCP deferred until there is a concrete iOS Tier 2 use case.

### 6. MCP does not affect Tier 0 or Tier 1 (confirmed)

MCP binary ships on all platforms but only starts when a Tier 2 project is active.
Tier 0/1 users have the binary; it never runs. SKILL.md files, role definitions, and
the file metaphor work identically with or without MCP. Non-AI extensibility is
completely preserved.

### 7. Approach B roadmapped (not scheduled)

Full MCP server (Skills as Tools + Notebooks as Resources + iOS in-process):
- `shopfloor://notebooks/{slug}` and `shopfloor://captures/{uuid}` resource URIs
- Persistent macOS service + in-process iOS server
- Deferred until: (a) Bill's dev loop reveals need for notebook context in MCP
  responses, or (b) a real Karen wants Claude Desktop access to her notebooks

### 8. Task 0 gates Phase 1 MCP sprint work

**Before any MCP sprint work:** Audit `App/Capture/Services/CaptureStore.swift` for
iOS-specific imports (UIKit, UIApplication, etc.). If found, extract `ShopfloorFileActor`
into a platform-agnostic module first. Do not schedule MCP sprint until Task 0 is clean.

## Reviewer Concerns (sprint-level, not design-level)

Flagged by adversarial spec review for resolution during sprint planning:
1. Port collision at 9999 — no retry logic defined
2. stdio transport assumptions vs. Claude Desktop streaming expectations
3. Large `.shopfloor/` project handling (>10MB edge case)
4. CI/CD: macOS runner + exact test command undefined
5. Ship criteria test fixture: demo project with known particles needed

## Cross-Model Insights

Independent Opus subagent review surfaced:
- "The moat is the skill library and the role taxonomy, not the runtime." Correct framing.
- "Your MCP surface should be ONE tool: `storyengine_route`" — adopted.
- Near-term value is Bill's dev loop, not Karen's access — adopted as revised Premise 3.
- 48-hr build spec (stdio, macOS, Swift target, read-only) — used as implementation blueprint.

Design doc: `~/.gstack/projects/wm-j-ray-ShopFloor/wmjray-main-design-20260418-084517.md`

## Next Steps

1. **Sprint 4:** capture note from Share sheet UI (current priority, not blocked by MCP)
2. **Task 0:** audit `CaptureStore.swift` for iOS coupling before MCP sprint
3. **MCP Sprint (4 or 5):** build `App/MCPServer/` target per Phase 1 spec above
4. **The assignment:** open Claude Desktop, ask "what would it take for you to understand
   my story notebooks?" — that answer writes the Approach B resource spec
5. **Next design session:** `/plan-eng-review` to lock in MCP target architecture

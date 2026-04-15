# VERTICAL.md — StoryEngine Registration Contract
# Read by the Foreman at every session init. Validated before any skill fires.
# Any Fail-level error in this file blocks all AI execution for the session.
# Error taxonomy: Roles/foreman/ROLE.md
# Validation skill: Skills/system/vertical-registration/SKILL.md

name: storyengine
display_name: StoryEngine
version: "1.0"
description: >
  Fiction writing intelligence vertical for ShopFloor. First vertical.
  Targets fiction authors (Karen). Provides AI-assisted support for the full
  fiction writing pipeline: particle capture → premise development → greenlight
  → deep development → polish. Platform: iOS/macOS native app with iCloud sync.
vertical_id: storyengine
maintainer: bill


# ── Roles ───────────────────────────────────────────────────────────────────
# Five StoryEngine vertical roles. Foreman is a platform role and is not
# declared here — the Foreman reads this file, it is not registered by it.

roles:
  - id: acquisitions-editor
    path: Roles/verticals/storyengine/acquisitions-editor/ROLE.md

  - id: publisher
    path: Roles/verticals/storyengine/publisher/ROLE.md

  - id: developmental-editor
    path: Roles/verticals/storyengine/developmental-editor/ROLE.md

  - id: proofreader
    path: Roles/verticals/storyengine/proofreader/ROLE.md

  - id: managing-editor
    path: Roles/verticals/storyengine/managing-editor/ROLE.md


# ── Skills ──────────────────────────────────────────────────────────────────
# Vertical-owned skills only. Foreman's platform skills (vertical-registration,
# session-init, context-index-generator, etc.) belong to the platform and are
# not declared here.
#
# skill_tier:               1=floor management  2=quality control  3=production
# product_tier_compatibility: 0=Stash (no AI)  1=Prompt Cookbook  2=Hyperdrive

skills:
  - id: starting-lineup
    path: Skills/verticals/storyengine/creative/starting-lineup/SKILL.md
    skill_tier: 3
    role: acquisitions-editor
    product_tier_compatibility: [1, 2]

  - id: greenlight-review
    path: Skills/verticals/storyengine/creative/greenlight-review/SKILL.md
    skill_tier: 3
    role: publisher
    product_tier_compatibility: [1, 2]

# NOTE: skill-designer is a platform skill owned by the Foreman. It is not
# declared here. Platform skills are not registered in vertical contracts.


# ── Entity Types ────────────────────────────────────────────────────────────
# Vertical-owned entity types only. Platform entities — Scorecard, Role_Record,
# Team_Manifest, System_Manifest — are NOT declared here. They are managed by
# the platform using role-id naming (e.g., Scorecard_acquisitions-editor.json),
# not the sequential [PREFIX]-[NNNNN] entity ID system.
#
# The Foreman initializes one idCounter entry in manifest.json per prefix at
# project creation. Regex: ^[A-Z]{2,4}-[0-9]{5}$

entity_types:

  # — Noun Data Structures ——————————————————————————————————————————————————
  - prefix: CHR
    name: Character_Profile
    description: "A character in the story world"

  - prefix: CTG
    name: Conflict_Tag
    description: "A conflict instance linking character, scene, and wound"

  - prefix: ERA
    name: Era_Profile
    description: "A historical period or story era"

  - prefix: EVT
    name: Event_Profile
    description: "A plot event and its participants"

  - prefix: GRP
    name: Group_Profile
    description: "A named group of characters"

  - prefix: LOC
    name: Location_Profile
    description: "A place in the story world"

  - prefix: MOT
    name: Motif_Profile
    description: "A recurring symbolic element"

  - prefix: NAR
    name: Narrator_Profile
    description: "Narrator type and configuration"

  - prefix: OBJ
    name: Object_Profile
    description: "A significant object"

  - prefix: POV
    name: POV_Profile
    description: "Point of view configuration"

  - prefix: RGN
    name: Region_Profile
    description: "A geographic or story region"

  - prefix: REL
    name: Relationship_Profile
    description: "A relationship between two characters"

  - prefix: SCN
    name: Scene_Container
    description: "A scene and its structural metadata"

  - prefix: SLU
    name: Starting_Lineup
    description: "A Swain-model story premise artifact"

  - prefix: THM
    name: Theme_Statement
    description: "The story's thematic argument"

  - prefix: TML
    name: Timeline_Entry
    description: "A chronological event entry"

  - prefix: VOC
    name: Voice_Profile
    description: "Narrative voice and style configuration"

  - prefix: WND
    name: Wound_Profile
    description: "A character's psychological wound"

  - prefix: WTG
    name: Wound_Tag
    description: "A wound activation instance in a scene"

  # — Verb Data Structures ——————————————————————————————————————————————————
  - prefix: ABS
    name: Arc_Beat_Sheet
    description: "Character arc beat tracking"

  - prefix: CHP
    name: Chapter_Profile
    description: "A chapter and its constituent scenes"

  - prefix: CNT
    name: Continuity_Log
    description: "A continuity fact record"

  - prefix: PCG
    name: Pacing_Map
    description: "Scene-level pacing and tension tracking"

  - prefix: PTT
    name: Plot_Thread_Tracker
    description: "An open or closed plot thread"

  - prefix: RAC
    name: Relationship_Arc
    description: "The arc of a relationship between two characters"

  - prefix: RVL
    name: Revelation_Log
    description: "A plot revelation and its placement"

  - prefix: SIN
    name: Scene_Inventory
    description: "Project-wide scene list and metadata"

  - prefix: SUB
    name: Subplot_Profile
    description: "A subplot and its scenes"

  - prefix: TPT
    name: Turning_Point_Tag
    description: "A structural turning point in a scene"

  # — Scaffolding ————————————————————————————————————————————————————————————
  - prefix: ACT
    name: Act_Profile
    description: "A story act boundary and its contents"

  - prefix: BRG
    name: Beat_Registry
    description: "Beat sheet for the active framework"

  - prefix: CFB
    name: Custom_Framework_Builder
    description: "A user-defined story framework"

  - prefix: CFR
    name: Conformance_Report
    description: "A single framework conformance check result"

  - prefix: CNH
    name: Conformance_History
    description: "History of framework conformance checks"

  - prefix: FWS
    name: Framework_Selector
    description: "Active framework selection record"

  - prefix: SGL
    name: Structural_Gap_Log
    description: "Identified structural gaps"

  - prefix: SSP
    name: Story_Spine
    description: "Structural spine of the story"

  - prefix: TRG
    name: Thread_Registry
    description: "Registry of all active threads and subplots"

  # — Frameworks ————————————————————————————————————————————————————————————
  - prefix: FHJ
    name: Framework_Heros_Journey
    description: "Hero's Journey framework template"

  - prefix: FSC
    name: Framework_Save_The_Cat
    description: "Save the Cat framework template"

  - prefix: FSG
    name: Framework_Story_Grid
    description: "Story Grid framework template"

  - prefix: FSP
    name: Framework_Seven_Point
    description: "Seven Point Story Structure template"

  - prefix: FTA
    name: Framework_Three_Act
    description: "Three-Act Structure framework template"

  # — Operations (vertical-owned) ——————————————————————————————————————————
  # Project is a StoryEngine entity — tracks pipeline state, starting lineup,
  # intent context, abandonment history. Platform operations entities
  # (Scorecard, Role_Record, Team_Manifest, System_Manifest) are excluded.
  - prefix: PRJ
    name: Project
    description: "StoryEngine project state: pipeline, starting lineup, intent context"


# ── Schema Paths ─────────────────────────────────────────────────────────────
# Foreman validates these paths exist on disk (PATH_NOT_FOUND check).
# Operations/ included so the Skill Designer can reference all schema templates,
# including platform entity schemas used in cross-reference validation.

schema_paths:
  - Data Structures/Noun Data Structures/
  - Data Structures/Verb Data Structures/
  - Data Structures/Scaffolding/
  - Data Structures/Frameworks/
  - Data Structures/Operations/


# ── Context Indexes ──────────────────────────────────────────────────────────
# Generated by the Foreman (context-index-generator, Tier 1).
# Lazy: regenerated only when source files change since last generation.
# Skills declare needed indexes in contextFingerprint; session-init loads only those.
#
# NOTE on schema-index sources: Operations/ is included so the Skill Designer
# has full schema awareness. Platform entity entries (Scorecard, Role_Record,
# Team_Manifest, System_Manifest) appear in schema-index for cross-reference
# reference only — they are not vertical entity types and carry no id counters.

indexes:
  - id: schema-index
    label: "Schema Index"
    sources:
      - Data Structures/Noun Data Structures/
      - Data Structures/Verb Data Structures/
      - Data Structures/Scaffolding/
      - Data Structures/Frameworks/
      - Data Structures/Operations/
    output: .shopfloor/schema-index.json
    format: compact
    invalidatedBy: sources

  - id: role-index
    label: "Role Index"
    sources:
      - Roles/
    output: .shopfloor/role-index.json
    # NOTE: Roles/ is intentionally broad — covers both platform/ and verticals/
    # subdirectories. The Foreman's own ROLE.md is included so the Skill Designer
    # has full awareness of all roles when generating platform skills.
    format: compact
    invalidatedBy: sources


# ── Per-File Metadata Extensions ─────────────────────────────────────────────
# Fields appended to platform per-file metadata records for StoryEngine files.
#
# Platform-owned particle fields (isParticle, particleStatus, captureMethod,
# sourceApp, sourceURL, sourceType, lastSurfaced, surfaceCount) are NOT declared
# here — they are platform infrastructure available to all verticals automatically.
#
# Extension fields are namespaced by vertical_id to prevent cross-vertical
# conflicts. The Foreman checks these against platform-reserved field names
# (FIELD_NAME_CONFLICT) and against other registered verticals.

per_file_extensions:
  - field: storyengine_resonanceNote
    type: string
    description: >
      Karen's 'why' at the moment of particle promotion — what struck her,
      in her own words. Captured once, at promotion. Distinct from later
      classification notes. Most actionable signal for the Acquisitions Editor.

  - field: storyengine_linkedStartingLineup
    type: string
    description: >
      Entity ID of the Starting_Lineup this particle contributed to
      (e.g., SLU-00001). Null until the particle is placed into a premise.
      Written by the Acquisitions Editor skill on placement.

  - field: storyengine_captureEntityChips
    type: array
    items: string
    description: >
      Entity IDs tagged by Karen at capture time. Mixed entity types;
      type is encoded in the prefix (e.g., CHR-00001, SCN-00003, WND-00002).
      Represents Karen's in-the-moment associations, not formal object model links.


# ── Product Tier Compatibility ────────────────────────────────────────────────
# Which product tiers this vertical supports.
# 0=Stash (no AI)  1=Prompt Cookbook (prompts generated)  2=Hyperdrive (full AI)

product_tier_compatibility: [0, 1, 2]


# ── Data Directory ────────────────────────────────────────────────────────────
# Subdirectory name for vertical-specific data within .shopfloor/

data_directory: storyengine

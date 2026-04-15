#!/bin/bash
# validate-vertical.sh
# Tier 0 test: validate all paths declared in VERTICAL.md exist on disk.
# This is the manual equivalent of what the Foreman's vertical-registration
# skill does at PATH_NOT_FOUND check time.
#
# Usage: ./validate-vertical.sh
# Exit code: 0 = all paths valid, 1 = one or more paths missing

ERRORS=0
CHECKS=0

check_file() {
  local path="$1"
  local label="$2"
  CHECKS=$((CHECKS + 1))
  if [ -f "$path" ]; then
    echo "  OK    [$label] $path"
  else
    echo "  FAIL  [$label] $path"
    ERRORS=$((ERRORS + 1))
  fi
}

check_dir() {
  local path="$1"
  local label="$2"
  CHECKS=$((CHECKS + 1))
  if [ -d "$path" ]; then
    echo "  OK    [$label] $path"
  else
    echo "  FAIL  [$label] $path"
    ERRORS=$((ERRORS + 1))
  fi
}

echo "========================================"
echo "  ShopFloor Vertical Registration Check "
echo "  VERTICAL.md path validation (Tier 0)  "
echo "========================================"
echo ""

echo "--- VERTICAL.md contract file ---"
check_file "VERTICAL.md" "contract"
echo ""

echo "--- Role paths (roles[].path) ---"
check_file "Roles/verticals/storyengine/acquisitions-editor/ROLE.md" "role"
check_file "Roles/verticals/storyengine/publisher/ROLE.md"           "role"
check_file "Roles/verticals/storyengine/developmental-editor/ROLE.md" "role"
check_file "Roles/verticals/storyengine/proofreader/ROLE.md"         "role"
check_file "Roles/verticals/storyengine/managing-editor/ROLE.md"     "role"
echo ""

echo "--- Skill paths (skills[].path) ---"
check_file "Skills/verticals/storyengine/creative/starting-lineup/SKILL.md"       "skill"
check_file "Skills/verticals/storyengine/creative/greenlight-review/SKILL.md"  "skill"
check_file "Skills/verticals/storyengine/creative/character-creation/SKILL.md" "skill"
echo ""

echo "--- Schema paths (schema_paths[]) ---"
check_dir "Data Structures/Noun Data Structures/" "schema_path"
check_dir "Data Structures/Verb Data Structures/" "schema_path"
check_dir "Data Structures/Scaffolding/"          "schema_path"
check_dir "Data Structures/Frameworks/"           "schema_path"
check_dir "Data Structures/Operations/"           "schema_path"
echo ""

echo "--- Index source paths (indexes[].sources) ---"
check_dir "Data Structures/Noun Data Structures/" "index_source"
check_dir "Data Structures/Verb Data Structures/" "index_source"
check_dir "Data Structures/Scaffolding/"          "index_source"
check_dir "Data Structures/Frameworks/"           "index_source"
check_dir "Data Structures/Operations/"           "index_source"
check_dir "Roles/"                                "index_source"
echo ""

echo "--- Platform skills (not in VERTICAL.md, validated separately) ---"
check_file "Skills/platform/affinity-generator/SKILL.md"        "platform_skill"
check_file "Skills/platform/session-init/SKILL.md"             "platform_skill"
check_file "Skills/platform/halt-monitor/SKILL.md"             "platform_skill"
check_file "Skills/platform/transaction-manager/SKILL.md"      "platform_skill"
check_file "Skills/platform/vertical-registration/SKILL.md"    "platform_skill"
check_file "Skills/platform/context-index-generator/SKILL.md"  "platform_skill"
check_file "Skills/platform/rebuild/SKILL.md"                  "platform_skill"
check_file "Skills/platform/skill-designer/SKILL.md"           "platform_skill"
check_file "Roles/platform/foreman/ROLE.md"                    "platform_role"
echo ""

echo "========================================"
if [ "$ERRORS" -eq 0 ]; then
  echo "  PASS — $CHECKS checks, 0 failures"
  echo "  All declared paths exist on disk."
  echo "  Foreman vertical-registration would clear this project."
else
  echo "  FAIL — $CHECKS checks, $ERRORS failure(s)"
  echo "  Fix FAIL entries before running vertical-registration."
fi
echo "========================================"

exit $ERRORS

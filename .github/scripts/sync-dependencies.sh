#!/bin/bash
set -euo pipefail

# Sync dependencies from longhabit repository
# This script fetches files from the upstream longhabit repo and compares them with local versions

LONGHABIT_REPO="${LONGHABIT_REPO:-s-petr/longhabit}"
LONGHABIT_BRANCH="${LONGHABIT_BRANCH:-main}"
BASE_URL="https://raw.githubusercontent.com/${LONGHABIT_REPO}/${LONGHABIT_BRANCH}"

# Define file mappings: "upstream_path:local_path"
declare -a FILES=(
  "README.md:README.md"
  "backend/go.mod:backend/go.mod"
  "package.json:package.json"
  "eslint.config.mjs:eslint.config.mjs"
)

# Create temporary directory for comparison
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

CHANGED_FILES=()
HAS_CHANGES=false

echo "🔍 Checking for dependency updates from ${LONGHABIT_REPO}..."

# Function to sync README version requirements only
sync_readme_versions() {
  local upstream_file="$1"
  local local_file="$2"

  # Extract version requirement lines from upstream README
  # Looking for lines like: "- Go 1.25+" "- Node.js 24+" "- **PocketBase v0.34**"

  # Fetch upstream README
  curl -s "${BASE_URL}/README.md" > "${upstream_file}"

  # Extract the prerequisites section and tech stack versions
  local go_version=$(grep -E "Go [0-9]+\.[0-9]+\+" "${upstream_file}" | head -1 || echo "")
  local node_version=$(grep -E "Node\.js [0-9]+\+" "${upstream_file}" | head -1 || echo "")
  local pb_version=$(grep -E "\*\*PocketBase v[0-9]+\.[0-9]+\*\*" "${upstream_file}" | head -1 || echo "")

  # Check if any version has changed
  local current_go=$(grep -E "Go [0-9]+\.[0-9]+\+" "${local_file}" | head -1 || echo "")
  local current_node=$(grep -E "Node\.js [0-9]+\+" "${local_file}" | head -1 || echo "")
  local current_pb=$(grep -E "\*\*PocketBase v[0-9]+\.[0-9]+\*\*" "${local_file}" | head -1 || echo "")

  if [ "$go_version" != "$current_go" ] || [ "$node_version" != "$current_node" ] || [ "$pb_version" != "$current_pb" ]; then
    echo "  📝 README.md: Version requirements changed"

    # Update the local file with new version requirements
    if [ -n "$go_version" ] && [ "$go_version" != "$current_go" ]; then
      sed -i.bak "s/Go [0-9]\+\.[0-9]\++/${go_version##*- }/g" "${local_file}"
      echo "     - Go version updated"
    fi

    if [ -n "$node_version" ] && [ "$node_version" != "$current_node" ]; then
      sed -i.bak "s/Node\.js [0-9]\++/${node_version##*- }/g" "${local_file}"
      echo "     - Node.js version updated"
    fi

    if [ -n "$pb_version" ] && [ "$pb_version" != "$current_pb" ]; then
      sed -i.bak "s/\*\*PocketBase v[0-9]\+\.[0-9]\+\*\*/${pb_version##*- }/g" "${local_file}"
      echo "     - PocketBase version updated"
    fi

    # Remove backup files
    rm -f "${local_file}.bak"

    return 0  # Has changes
  else
    echo "  ✓ README.md: No version changes"
    return 1  # No changes
  fi
}

# Check each file for changes
for file_mapping in "${FILES[@]}"; do
  IFS=':' read -r upstream_path local_path <<< "$file_mapping"

  echo ""
  echo "Checking: $local_path"

  upstream_file="${TMP_DIR}/$(basename "$upstream_path")"

  # Special handling for README.md
  if [ "$local_path" = "README.md" ]; then
    if sync_readme_versions "$upstream_file" "$local_path"; then
      CHANGED_FILES+=("$local_path")
      HAS_CHANGES=true
    fi
    continue
  fi

  # Fetch file from longhabit
  if ! curl -sf "${BASE_URL}/${upstream_path}" > "${upstream_file}"; then
    echo "  ⚠️  Warning: Could not fetch ${upstream_path} from upstream"
    continue
  fi

  # Compare with local file
  if [ ! -f "$local_path" ]; then
    echo "  ⚠️  Warning: Local file $local_path does not exist"
    continue
  fi

  if ! diff -q "$upstream_file" "$local_path" > /dev/null 2>&1; then
    echo "  📝 Changes detected"
    # Copy the new version
    cp "$upstream_file" "$local_path"
    CHANGED_FILES+=("$local_path")
    HAS_CHANGES=true
  else
    echo "  ✓ No changes"
  fi
done

echo ""
echo "================================================"

# Output results for GitHub Actions
if [ "$HAS_CHANGES" = true ]; then
  echo "✅ Changes detected in ${#CHANGED_FILES[@]} file(s)"
  echo "Changed files:"
  printf '  - %s\n' "${CHANGED_FILES[@]}"

  # Export for GitHub Actions
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "has_changes=true" >> "$GITHUB_OUTPUT"
    # Join array with commas for output
    changed_files_str=$(IFS=,; echo "${CHANGED_FILES[*]}")
    echo "changed_files=$changed_files_str" >> "$GITHUB_OUTPUT"
  fi

  exit 0
else
  echo "ℹ️  No changes detected - all files are in sync"

  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "has_changes=false" >> "$GITHUB_OUTPUT"
    echo "changed_files=" >> "$GITHUB_OUTPUT"
  fi

  exit 0
fi

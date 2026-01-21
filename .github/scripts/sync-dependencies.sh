#!/bin/bash
set -euo pipefail

# Sync dependencies from longhabit repository
# This script fetches files from the upstream longhabit repo and compares them with local versions

LONGHABIT_REPO="${LONGHABIT_REPO:-s-petr/longhabit}"
LONGHABIT_BRANCH="${LONGHABIT_BRANCH:-main}"

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

echo "🔄 Fetching upstream repository ${LONGHABIT_REPO}@${LONGHABIT_BRANCH}..."

UPSTREAM_DIR="${TMP_DIR}/upstream"
CLONE_URL="https://github.com/${LONGHABIT_REPO}.git"

if [ -n "${GH_TOKEN:-}" ]; then
  CLONE_URL="https://x-access-token:${GH_TOKEN}@github.com/${LONGHABIT_REPO}.git"
fi

if ! git clone --depth=1 --branch "$LONGHABIT_BRANCH" "$CLONE_URL" "$UPSTREAM_DIR" >/dev/null 2>&1; then
  echo "❌ Failed to clone upstream repository $LONGHABIT_REPO (branch: $LONGHABIT_BRANCH)"
  exit 1
fi

echo "✓ Upstream repository cloned to $UPSTREAM_DIR"

CHANGED_FILES=()
HAS_CHANGES=false

echo "🔍 Checking for dependency updates from ${LONGHABIT_REPO}..."

# Function to sync README version requirements only
sync_readme_versions() {
  local upstream_file="$1"
  local local_file="$2"

  # Extract version requirement lines from upstream README
  # Looking for lines like: "- Go 1.25+" "- Node.js 24+" "- **PocketBase v0.34**"
  if [ ! -f "$upstream_file" ]; then
    echo "  ⚠️  Warning: Upstream README not available"
    return 1
  fi

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

# Parse require directives from go.mod as "module version"
parse_go_mod_requires() {
  local file="$1"
  awk '
    $1 == "require" && $2 != "(" { print $2, $3; next }
    $1 == "require" && $2 == "(" { inreq = 1; next }
    inreq && $1 == ")" { inreq = 0; next }
    inreq { print $1, $2 }
  ' "$file"
}

# Sync only overlapping Go dependency versions (leave module path and extras intact)
sync_go_mod_versions() {
  local upstream_file="$1"
  local local_file="$2"

  if [ ! -f "$upstream_file" ]; then
    echo "  ⚠️  Warning: Upstream go.mod not available"
    return 1
  fi

  if [ ! -f "$local_file" ]; then
    echo "  ⚠️  Warning: Local file $local_file does not exist"
    return 1
  fi

  declare -A upstream_versions=()
  while read -r module version; do
    if [ -n "${module:-}" ] && [ -n "${version:-}" ]; then
      upstream_versions["$module"]="$version"
    fi
  done < <(parse_go_mod_requires "$upstream_file")

  local changed=false
  local local_dir
  local_dir=$(dirname "$local_file")

  while read -r module version; do
    if [ -z "${module:-}" ] || [ -z "${version:-}" ]; then
      continue
    fi

    if [ -n "${upstream_versions[$module]+set}" ] && [ "${upstream_versions[$module]}" != "$version" ]; then
      echo "  📝 $module: $version -> ${upstream_versions[$module]}"
      (cd "$local_dir" && go mod edit -require="$module@${upstream_versions[$module]}")
      changed=true
    fi
  done < <(parse_go_mod_requires "$local_file")

  if [ "$changed" = true ]; then
    echo "  📝 backend/go.mod: Overlapping dependency versions updated"
    return 0
  fi

  echo "  ✓ backend/go.mod: No overlapping dependency version changes"
  return 1
}

# Sync only overlapping NPM dependency versions (leave extra deps intact)
sync_package_json_versions() {
  local upstream_file="$1"
  local local_file="$2"

  if [ ! -f "$upstream_file" ]; then
    echo "  ⚠️  Warning: Upstream package.json not available"
    return 1
  fi

  if [ ! -f "$local_file" ]; then
    echo "  ⚠️  Warning: Local file $local_file does not exist"
    return 1
  fi

  if ! command -v node >/dev/null 2>&1; then
    echo "  ⚠️  Warning: node is not available to sync package.json"
    return 1
  fi

  local changed
  changed=$(node <<'NODE' "$upstream_file" "$local_file"
const fs = require('fs')
const [,, upstreamPath, localPath] = process.argv
const upstream = JSON.parse(fs.readFileSync(upstreamPath, 'utf8'))
const local = JSON.parse(fs.readFileSync(localPath, 'utf8'))

// Only sync dependency sections to avoid overwriting whitelabel metadata
const sections = [
  'dependencies',
  'devDependencies',
  'peerDependencies',
  'optionalDependencies',
  'overrides',
  'resolutions'
]

let changed = false
for (const section of sections) {
  const upstreamSection = upstream[section]
  const localSection = Object.prototype.hasOwnProperty.call(local, section) ? local[section] : undefined

  if (upstreamSection === undefined) {
    if (localSection !== undefined) {
      delete local[section]
      changed = true
    }
    continue
  }

  const same = JSON.stringify(upstreamSection) === JSON.stringify(localSection)
  if (!same) {
    local[section] = upstreamSection
    changed = true
  }
}

if (changed) {
  fs.writeFileSync(localPath, JSON.stringify(local, null, 2) + '\n')
}

process.stdout.write(changed ? 'true' : 'false')
NODE
)

  if [ "$changed" = "true" ]; then
    echo "  📝 package.json: Dependency sections synced from upstream"
    return 0
  fi

  echo "  ✓ package.json: No dependency section changes"
  return 1
}

# Sync overlapping ESLint config entries (keep local-only customizations)
sync_eslint_config_overlap() {
  local upstream_file="$1"
  local local_file="$2"

  if [ ! -f "$upstream_file" ]; then
    echo "  ⚠️  Warning: Upstream eslint.config.mjs not available"
    return 1
  fi

  if [ ! -f "$local_file" ]; then
    echo "  ⚠️  Warning: Local file $local_file does not exist"
    return 1
  fi

  if ! command -v node >/dev/null 2>&1; then
    echo "  ⚠️  Warning: node is not available to sync eslint.config.mjs"
    return 1
  fi

  local changed
  changed=$(node <<'NODE' "$upstream_file" "$local_file"
const fs = require('fs')
const [,, upstreamPath, localPath] = process.argv
const upstreamText = fs.readFileSync(upstreamPath, 'utf8')
const localText = fs.readFileSync(localPath, 'utf8')

function findBlock(text, key) {
  const regex = new RegExp(`\\b${key}\\s*:`)
  const match = regex.exec(text)
  if (!match) return null
  const keyIndex = match.index
  const braceStart = text.indexOf('{', keyIndex)
  if (braceStart === -1) return null
  const end = findMatchingBrace(text, braceStart)
  if (end === -1) return null
  return { keyIndex, start: braceStart, end }
}

function findMatchingBrace(text, start) {
  let depth = 0
  let inString = false
  let stringChar = ''
  let inTemplate = false
  let inSingleLine = false
  let inMultiLine = false

  for (let i = start; i < text.length; i += 1) {
    const ch = text[i]
    const next = text[i + 1]

    if (inSingleLine) {
      if (ch === '\n') inSingleLine = false
      continue
    }
    if (inMultiLine) {
      if (ch === '*' && next === '/') {
        inMultiLine = false
        i += 1
      }
      continue
    }
    if (inString) {
      if (ch === '\\') {
        i += 1
        continue
      }
      if (ch === stringChar) inString = false
      continue
    }
    if (inTemplate) {
      if (ch === '\\') {
        i += 1
        continue
      }
      if (ch === '`') inTemplate = false
      continue
    }

    if (ch === '/' && next === '/') {
      inSingleLine = true
      i += 1
      continue
    }
    if (ch === '/' && next === '*') {
      inMultiLine = true
      i += 1
      continue
    }
    if (ch === '"' || ch === "'") {
      inString = true
      stringChar = ch
      continue
    }
    if (ch === '`') {
      inTemplate = true
      continue
    }

    if (ch === '{') depth += 1
    if (ch === '}') {
      depth -= 1
      if (depth === 0) return i
    }
  }

  return -1
}

function splitEntries(objText) {
  const entries = []
  let start = 0
  let depth = 0
  let inString = false
  let stringChar = ''
  let inTemplate = false
  let inSingleLine = false
  let inMultiLine = false

  for (let i = 0; i < objText.length; i += 1) {
    const ch = objText[i]
    const next = objText[i + 1]

    if (inSingleLine) {
      if (ch === '\n') inSingleLine = false
      continue
    }
    if (inMultiLine) {
      if (ch === '*' && next === '/') {
        inMultiLine = false
        i += 1
      }
      continue
    }
    if (inString) {
      if (ch === '\\') {
        i += 1
        continue
      }
      if (ch === stringChar) inString = false
      continue
    }
    if (inTemplate) {
      if (ch === '\\') {
        i += 1
        continue
      }
      if (ch === '`') inTemplate = false
      continue
    }

    if (ch === '/' && next === '/') {
      inSingleLine = true
      i += 1
      continue
    }
    if (ch === '/' && next === '*') {
      inMultiLine = true
      i += 1
      continue
    }
    if (ch === '"' || ch === "'") {
      inString = true
      stringChar = ch
      continue
    }
    if (ch === '`') {
      inTemplate = true
      continue
    }

    if (ch === '{' || ch === '[' || ch === '(') depth += 1
    if (ch === '}' || ch === ']' || ch === ')') depth -= 1

    if (ch === ',' && depth === 0) {
      const entry = objText.slice(start, i).trim()
      if (entry) entries.push(entry)
      start = i + 1
    }
  }

  const last = objText.slice(start).trim()
  if (last) entries.push(last)
  return entries
}

function getEntryKey(entry) {
  const trimmed = entry.trim()
  if (trimmed.startsWith('...')) return null

  let depth = 0
  let inString = false
  let stringChar = ''
  let inTemplate = false

  for (let i = 0; i < trimmed.length; i += 1) {
    const ch = trimmed[i]
    const next = trimmed[i + 1]

    if (inString) {
      if (ch === '\\') {
        i += 1
        continue
      }
      if (ch === stringChar) inString = false
      continue
    }
    if (inTemplate) {
      if (ch === '\\') {
        i += 1
        continue
      }
      if (ch === '`') inTemplate = false
      continue
    }

    if (ch === '"' || ch === "'") {
      inString = true
      stringChar = ch
      continue
    }
    if (ch === '`') {
      inTemplate = true
      continue
    }
    if (ch === '{' || ch === '[' || ch === '(') depth += 1
    if (ch === '}' || ch === ']' || ch === ')') depth -= 1

    if (ch === ':' && depth === 0) {
      const keyPart = trimmed.slice(0, i).trim()
      return normalizeKey(keyPart)
    }

    if (ch === '/' && next === '*') {
      i += 1
      while (i < trimmed.length && !(trimmed[i] === '*' && trimmed[i + 1] === '/')) i += 1
      i += 1
      continue
    }
    if (ch === '/' && next === '/') {
      break
    }
  }

  return null
}

function normalizeKey(keyPart) {
  if (!keyPart) return null
  const trimmed = keyPart.trim()
  const quote = trimmed[0]
  if ((quote === "'" || quote === '"') && trimmed[trimmed.length - 1] === quote) {
    return trimmed.slice(1, -1)
  }
  return trimmed
}

function normalizeIndent(entry) {
  const lines = entry.replace(/\s+$/, '').split('\n')
  const nonEmpty = lines.filter((line) => line.trim().length > 0)
  if (nonEmpty.length === 0) return entry.trim()
  const minIndent = Math.min(...nonEmpty.map((line) => line.match(/^\s*/)[0].length))
  const trimmed = lines.map((line) => line.slice(minIndent)).join('\n')
  return trimmed.trim()
}

function formatEntry(entry, indent) {
  const normalized = normalizeIndent(entry)
  const lines = normalized.split('\n')
  return lines.map((line) => (line.length ? indent + line : line)).join('\n')
}

function normalizeEntry(entry) {
  return entry.replace(/\s+/g, ' ').trim()
}

function getIndent(text, index) {
  const lineStart = text.lastIndexOf('\n', index)
  const start = lineStart === -1 ? 0 : lineStart + 1
  const line = text.slice(start, index)
  const match = line.match(/^\s*/)
  return match ? match[0] : ''
}

function mergeBlock(currentText, upstreamText, key) {
  const localBlock = findBlock(currentText, key)
  const upstreamBlock = findBlock(upstreamText, key)
  if (!localBlock || !upstreamBlock) {
    return { text: currentText, changed: false }
  }

  const localObj = currentText.slice(localBlock.start + 1, localBlock.end)
  const upstreamObj = upstreamText.slice(upstreamBlock.start + 1, upstreamBlock.end)

  const localEntries = splitEntries(localObj)
  const upstreamEntries = splitEntries(upstreamObj)
  const upstreamMap = new Map()
  upstreamEntries.forEach((entry) => {
    const key = getEntryKey(entry)
    if (key) upstreamMap.set(key, entry)
  })

  let changed = false
  const mergedEntries = localEntries.map((entry) => {
    const entryKey = getEntryKey(entry)
    if (entryKey && upstreamMap.has(entryKey)) {
      const upstreamEntry = upstreamMap.get(entryKey)
      if (normalizeEntry(entry) !== normalizeEntry(upstreamEntry)) {
        changed = true
      }
      return upstreamEntry
    }
    return entry
  })

  if (!changed) {
    return { text: currentText, changed: false }
  }

  const indent = getIndent(currentText, localBlock.keyIndex)
  const entryIndent = indent + '  '
  const formattedEntries = mergedEntries.map((entry) => formatEntry(entry, entryIndent)).join(',\n')
  const rebuilt = `\n${formattedEntries}\n${indent}`
  const updatedText = currentText.slice(0, localBlock.start + 1) + rebuilt + currentText.slice(localBlock.end)

  return { text: updatedText, changed: true }
}

let resultText = localText
let anyChanged = false
for (const key of ['plugins', 'rules']) {
  const result = mergeBlock(resultText, upstreamText, key)
  resultText = result.text
  if (result.changed) anyChanged = true
}

if (anyChanged) {
  fs.writeFileSync(localPath, resultText)
}

process.stdout.write(anyChanged ? 'true' : 'false')
NODE
)

  if [ "$changed" = "true" ]; then
    echo "  📝 eslint.config.mjs: Overlapping config entries updated"
    return 0
  fi

  echo "  ✓ eslint.config.mjs: No overlapping config changes"
  return 1
}

# Check each file for changes
for file_mapping in "${FILES[@]}"; do
  IFS=':' read -r upstream_path local_path <<< "$file_mapping"

  echo ""
  echo "Checking: $local_path"

  upstream_file="${UPSTREAM_DIR}/${upstream_path}"

  if [ ! -f "$upstream_file" ]; then
    echo "  ⚠️  Warning: Could not find ${upstream_path} in upstream clone"
    continue
  fi

  # Special handling for README.md and dependency files
  if [ "$local_path" = "README.md" ]; then
    if sync_readme_versions "$upstream_file" "$local_path"; then
      CHANGED_FILES+=("$local_path")
      HAS_CHANGES=true
    fi
    continue
  fi

  if [ "$local_path" = "backend/go.mod" ]; then
    if sync_go_mod_versions "$upstream_file" "$local_path"; then
      CHANGED_FILES+=("$local_path")
      HAS_CHANGES=true
    fi
    continue
  fi

  if [ "$local_path" = "package.json" ]; then
    if sync_package_json_versions "$upstream_file" "$local_path"; then
      CHANGED_FILES+=("$local_path")
      HAS_CHANGES=true
    fi
    continue
  fi

  if [ "$local_path" = "eslint.config.mjs" ]; then
    if sync_eslint_config_overlap "$upstream_file" "$local_path"; then
      CHANGED_FILES+=("$local_path")
      HAS_CHANGES=true
    fi
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

#!/usr/bin/env bash
set -euo pipefail

################################################################################
# Comprehensive Frontend Scaffold Script
#
# This script automates the full NEW_PROJECT_PLAN.md setup:
# 1. Interactive project configuration (name + Go module path)
# 2. Scaffold Vite React-TS frontend
# 3. Update configuration files (vite.config.ts, package.json, eslint, prettier, tsconfig)
# 4. Update backend references (go.mod, Dockerfile, docker-compose.yml)
# 5. Cleanup old files
# 6. Run npm install
#
# Run from the repo root: ./scripts/scaffold-frontend.sh
################################################################################

die() {
  echo "Error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

print_header() {
  echo ""
  echo "========================================"
  echo "$1"
  echo "========================================"
}

# Validate project name (alphanumeric, hyphens, underscores only)
validate_project_name() {
  local name="$1"
  if [[ ! "$name" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
    return 1
  fi
  return 0
}

# Validate Go module path (basic format check)
validate_go_module() {
  local module="$1"
  if [[ ! "$module" =~ ^[a-zA-Z0-9.-]+/[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
    return 1
  fi
  return 0
}

################################################################################
# Precondition checks
################################################################################

if [[ ! -f "package.json" || ! -d "backend" || ! -f "vite.config.ts" ]]; then
  die "Run this script from the repo root (missing package.json, backend/, or vite.config.ts)."
fi

require_command npm
require_command mktemp
require_command sed
require_command jq

################################################################################
# Interactive configuration
################################################################################

print_header "Project Configuration"

# Prompt for project name
while true; do
  read -rp "Enter project name (e.g., my-saas-app): " PROJECT_NAME
  if [[ -z "$PROJECT_NAME" ]]; then
    echo "Project name cannot be empty."
    continue
  fi
  if validate_project_name "$PROJECT_NAME"; then
    break
  else
    echo "Invalid project name. Use letters, numbers, hyphens, or underscores. Must start with a letter."
  fi
done

# Prompt for Go module path
while true; do
  read -rp "Enter Go module path (e.g., github.com/username/$PROJECT_NAME): " GO_MODULE
  if [[ -z "$GO_MODULE" ]]; then
    echo "Go module path cannot be empty."
    continue
  fi
  if validate_go_module "$GO_MODULE"; then
    break
  else
    echo "Invalid Go module path. Expected format: github.com/org/project"
  fi
done

echo ""
echo "Configuration:"
echo "  Project name: $PROJECT_NAME"
echo "  Go module:    $GO_MODULE"
echo ""
read -rp "Proceed with these settings? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

################################################################################
# Check for existing frontend directory
################################################################################

if [[ -d "frontend" ]]; then
  echo ""
  echo "Warning: 'frontend/' directory already exists."
  read -rp "Delete existing frontend/ and continue? (y/N): " DELETE_FRONTEND
  if [[ "$DELETE_FRONTEND" =~ ^[Yy]$ ]]; then
    rm -rf frontend
    echo "Deleted existing frontend/ directory."
  else
    die "Cannot proceed with existing frontend/ directory."
  fi
fi

################################################################################
# Step 1: Scaffold Vite React-TS frontend
################################################################################

print_header "Step 1: Scaffolding Vite React-TS Frontend"

tmp_parent="$(mktemp -d)"
trap 'rm -rf "$tmp_parent"' EXIT

(
  cd "$tmp_parent"
  # Use CI=true to skip interactive prompts and prevent auto-install/start
  CI=true npm create vite@latest "vite-template" -- --template react-ts
)

mkdir -p frontend
cp -R "$tmp_parent/vite-template/index.html" frontend/
cp -R "$tmp_parent/vite-template/public" frontend/
cp -R "$tmp_parent/vite-template/src" frontend/

echo "Frontend scaffolded into ./frontend"

################################################################################
# Step 2: Update vite.config.ts
################################################################################

print_header "Step 2: Updating vite.config.ts"

cat > vite.config.ts << 'VITE_CONFIG_EOF'
import react from '@vitejs/plugin-react'
import path from 'node:path'
import { defineConfig, loadEnv } from 'vite'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const backendUrl = env.VITE_BACKEND_URL || 'http://localhost:8090'

  return {
    root: 'frontend',
    plugins: [react()],
    build: {
      outDir: '../backend/dist',
      emptyOutDir: true
    },
    resolve: {
      alias: { '@': path.resolve(__dirname, 'frontend/src') }
    },
    server: {
      proxy: {
        '/api': { target: backendUrl, changeOrigin: true }
      }
    }
  }
})
VITE_CONFIG_EOF

echo "Updated vite.config.ts"

################################################################################
# Step 3: Update package.json
################################################################################

print_header "Step 3: Updating package.json"

# Read dependencies from the Vite template's package.json
VITE_PKG="$tmp_parent/vite-template/package.json"

# Extract Vite template dependencies as JSON
VITE_DEPS=$(jq '.dependencies // {}' "$VITE_PKG")
VITE_DEV_DEPS=$(jq '.devDependencies // {}' "$VITE_PKG")

# Extra dev dependencies for better DX (ESLint plugins, Prettier, etc.)
# These are merged with Vite's defaults, with our versions taking precedence
EXTRA_DEV_DEPS='{
  "@typescript-eslint/eslint-plugin": "^8.49.0",
  "@typescript-eslint/parser": "^8.49.0",
  "eslint-config-prettier": "^10.1.8",
  "eslint-plugin-react": "^7.37.5",
  "eslint-plugin-react-hooks": "^5.2.0",
  "eslint-plugin-react-refresh": "^0.4.20",
  "globals": "^16.3.0",
  "prettier": "^3.7.4"
}'

# Merge Vite devDependencies with our extras (our extras take precedence)
MERGED_DEV_DEPS=$(echo "$VITE_DEV_DEPS" "$EXTRA_DEV_DEPS" | jq -s 'add')

# Build the final package.json
jq -n \
  --arg name "$PROJECT_NAME" \
  --argjson deps "$VITE_DEPS" \
  --argjson devDeps "$MERGED_DEV_DEPS" \
  --arg projName "$PROJECT_NAME" \
  '{
    name: $name,
    version: "0.1.0",
    type: "module",
    scripts: {
      "dev:client": "vite dev",
      "dev:server": "cd backend && go run . --dir=../db serve",
      "dev": "npm run dev:client & npm run dev:server",
      "build:client": "npm run lint && vite build",
      "build:server": ("cd backend && CGO_ENABLED=0 go build -tags production -o ../" + $projName),
      "build": "npm run build:client && npm run build:server",
      "preview": ("./" + $projName + " serve"),
      "compose": "docker compose up --build -d",
      "pretty": "prettier frontend/src --write",
      "lint": "tsc --noEmit && eslint frontend/src"
    },
    dependencies: $deps,
    devDependencies: $devDeps
  }' > package.json

echo "Updated package.json (merged Vite template deps with extra dev tooling)"

################################################################################
# Step 4: Update eslint.config.mjs
################################################################################

print_header "Step 4: Updating eslint.config.mjs"

cat > eslint.config.mjs << 'ESLINT_CONFIG_EOF'
import tsPlugin from '@typescript-eslint/eslint-plugin'
import tsParser from '@typescript-eslint/parser'
import prettierConfig from 'eslint-config-prettier'
import reactPlugin from 'eslint-plugin-react'
import reactHooksPlugin from 'eslint-plugin-react-hooks'
import reactRefreshPlugin from 'eslint-plugin-react-refresh'
import globals from 'globals'

export default [
  {
    files: ['frontend/src/**/*.{ts,tsx}'],
    settings: { react: { version: 'detect' } },
    languageOptions: {
      parser: tsParser,
      parserOptions: {
        ecmaFeatures: { jsx: true },
        ecmaVersion: 'latest'
      },
      globals: { ...globals.browser }
    },
    plugins: {
      '@typescript-eslint': tsPlugin,
      react: reactPlugin,
      'react-hooks': reactHooksPlugin,
      'react-refresh': reactRefreshPlugin
    },
    rules: {
      ...reactPlugin.configs.recommended.rules,
      ...reactHooksPlugin.configs.recommended.rules,
      'react/react-in-jsx-scope': 'off',
      'react-refresh/only-export-components': ['warn', { allowConstantExport: true }]
    }
  },
  prettierConfig
]
ESLINT_CONFIG_EOF

echo "Updated eslint.config.mjs"

################################################################################
# Step 5: Update .prettierrc.json
################################################################################

print_header "Step 5: Updating .prettierrc.json"

cat > .prettierrc.json << 'PRETTIER_CONFIG_EOF'
{
  "trailingComma": "none",
  "tabWidth": 2,
  "semi": false,
  "singleQuote": true,
  "singleAttributePerLine": false,
  "bracketSameLine": true,
  "jsxSingleQuote": true,
  "printWidth": 80,
  "endOfLine": "auto"
}
PRETTIER_CONFIG_EOF

echo "Updated .prettierrc.json"

################################################################################
# Step 6: Update tsconfig.json
################################################################################

print_header "Step 6: Updating tsconfig.json"

cat > tsconfig.json << 'TSCONFIG_EOF'
{
  "compilerOptions": {
    "target": "ESNext",
    "useDefineForClassFields": true,
    "lib": ["ESNext", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "paths": { "@/*": ["./frontend/src/*"] }
  },
  "include": ["frontend/src"]
}
TSCONFIG_EOF

echo "Updated tsconfig.json"

################################################################################
# Step 7: Update backend/go.mod and Go import paths
################################################################################

print_header "Step 7: Updating backend/go.mod and Go imports"

# Get the old module path from go.mod
OLD_MODULE=$(head -1 backend/go.mod | sed 's/^module //')

# Update the module declaration in go.mod
sed -i.bak "1s|^module .*|module $GO_MODULE|" backend/go.mod
rm -f backend/go.mod.bak

# Update all Go files that import from the old module path
find backend -name '*.go' -type f | while read -r gofile; do
  if grep -q "$OLD_MODULE" "$gofile"; then
    sed -i.bak "s|$OLD_MODULE|$GO_MODULE|g" "$gofile"
    rm -f "${gofile}.bak"
    echo "  Updated imports in: $gofile"
  fi
done

echo "Updated backend/go.mod module path to: $GO_MODULE"

################################################################################
# Step 8: Update Dockerfile
################################################################################

print_header "Step 8: Updating Dockerfile"

sed -i.bak "s|go build -tags production -o saas-template|go build -tags production -o $PROJECT_NAME|g" Dockerfile
sed -i.bak "s|COPY --from=builder-go /app/saas-template|COPY --from=builder-go /app/$PROJECT_NAME|g" Dockerfile
sed -i.bak "s|\"/app/saas-template\"|\"/app/$PROJECT_NAME\"|g" Dockerfile
rm -f Dockerfile.bak

echo "Updated Dockerfile binary references"

################################################################################
# Step 9: Update docker-compose.yml
################################################################################

print_header "Step 9: Updating docker-compose.yml"

sed -i.bak "s|saas-template:|$PROJECT_NAME:|g" docker-compose.yml
sed -i.bak "s|container_name: saas-template|container_name: $PROJECT_NAME|g" docker-compose.yml
rm -f docker-compose.yml.bak

echo "Updated docker-compose.yml service and container names"

################################################################################
# Step 10: Cleanup
################################################################################

print_header "Step 10: Cleanup"

# Remove root index.html if it exists
if [[ -f "index.html" ]]; then
  rm -f index.html
  echo "Removed root index.html"
else
  echo "No root index.html to remove"
fi

################################################################################
# Step 11: Run npm install
################################################################################

print_header "Step 11: Installing Dependencies"

npm install

echo "Dependencies installed"

################################################################################
# Post-setup guidance
################################################################################

print_header "Setup Complete!"

echo ""
echo "Your project '$PROJECT_NAME' has been configured."
echo ""
echo "Remaining manual steps:"
echo ""
echo "  1. Update email template branding in backend/templates/"
echo "     - base.layout.gohtml: Company name, meta tags"
echo "     - styles.partial.gohtml: Brand colors, fonts"
echo "     - verify-email.page.gohtml: Subject line, copy"
echo "     - reset-password.page.gohtml: Subject line, copy"
echo "     - auth-alert.page.gohtml: Subject line, copy"
echo ""
echo "  2. Update sender email in backend/notifier/email.go:"
echo "     From: \"noreply@YOUR_DOMAIN.com\""
echo ""
echo "  3. Add to .gitignore:"
echo "     $PROJECT_NAME"
echo "     *.exe"
echo "     db/"
echo "     backend/dist/"
echo "     .env"
echo "     .env.local"
echo ""
echo "  4. Create a superuser for PocketBase admin:"
echo "     ./$PROJECT_NAME superuser upsert admin@example.com yourpassword"
echo ""
echo "Quick start commands:"
echo ""
echo "  npm run dev      - Start dev servers (frontend:5173, backend:8090)"
echo "  npm run build    - Build frontend and backend"
echo "  npm run preview  - Run production binary"
echo ""

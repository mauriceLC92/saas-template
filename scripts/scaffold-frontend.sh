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
# 7. Remove template-specific files (CLAUDE.md, README.md, NEW_PROJECT_PLAN.md)
# 8. Initialize fresh git repository with single initial commit
#
# Run from the repo root: ./scripts/scaffold-frontend.sh
################################################################################

# Catalyst UI Kit configuration
CATALYST_SOURCE="${CATALYST_SOURCE:-$HOME/Downloads/adamwathanss-tuibeta 2/adamwathanss-tuibeta/catalyst-ui-kit}"
INCLUDE_CATALYST=""

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

# Auto-generate Go module path from project name
GO_MODULE="github.com/mauriceLC92/$PROJECT_NAME"

echo ""
echo "Configuration:"
echo "  Project name: $PROJECT_NAME"
echo "  Go module:    $GO_MODULE (auto-generated)"
echo ""
read -rp "Proceed with these settings? (Y/n): " CONFIRM
CONFIRM=${CONFIRM:-y}  # Default to 'y' if empty
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

################################################################################
# Clean up existing frontend directory
################################################################################

if [[ -d "frontend" ]]; then
  echo ""
  echo "Removing existing frontend/ directory..."
  rm -rf frontend
  echo "Deleted existing frontend/ directory."
fi

################################################################################
# Step 1: Scaffold Vite React-TS frontend
################################################################################

print_header "Step 1: Scaffolding Vite React-TS Frontend"

tmp_parent="$(mktemp -d)"
trap 'rm -rf "$tmp_parent"' EXIT

(
  cd "$tmp_parent"
  # Use --no-interactive flag to skip prompts and prevent auto-install/start
  npm create vite@latest "vite-template" -- --template react-ts --no-interactive
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

# Extra production dependencies for QoL features (TanStack, PocketBase, Zod)
EXTRA_DEPS='{
  "@tanstack/react-query": "^5.84.2",
  "@tanstack/react-router": "^1.131.27",
  "pocketbase": "^0.26.2",
  "zod": "^4.1.13"
}'

# Add Catalyst dependencies if user opted in
if [[ "$INCLUDE_CATALYST" =~ ^[Yy]$ ]]; then
  CATALYST_DEPS='{
    "@headlessui/react": "^2.2.0",
    "framer-motion": "^11.15.0",
    "clsx": "^2.1.1"
  }'
  EXTRA_DEPS=$(echo "$EXTRA_DEPS" "$CATALYST_DEPS" | jq -s 'add')
fi

# Extra dev dependencies for better DX (ESLint plugins, Prettier, devtools, etc.)
# These are merged with Vite's defaults, with our versions taking precedence
EXTRA_DEV_DEPS='{
  "@tanstack/react-query-devtools": "^5.84.2",
  "@tanstack/react-router-devtools": "^1.131.5",
  "@typescript-eslint/eslint-plugin": "^8.49.0",
  "@typescript-eslint/parser": "^8.49.0",
  "eslint-config-prettier": "^10.1.8",
  "eslint-plugin-react": "^7.37.5",
  "eslint-plugin-react-hooks": "^5.2.0",
  "eslint-plugin-react-refresh": "^0.4.20",
  "globals": "^16.3.0",
  "prettier": "^3.7.4"
}'

# Merge Vite deps with our extras (our extras take precedence)
MERGED_DEPS=$(echo "$VITE_DEPS" "$EXTRA_DEPS" | jq -s 'add')
MERGED_DEV_DEPS=$(echo "$VITE_DEV_DEPS" "$EXTRA_DEV_DEPS" | jq -s 'add')

# Build the final package.json
jq -n \
  --arg name "$PROJECT_NAME" \
  --argjson deps "$MERGED_DEPS" \
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

echo "Updated package.json (merged Vite deps with TanStack, PocketBase, Zod, and dev tooling)"

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
# Optional: Catalyst UI Kit
################################################################################

print_header "Optional: Catalyst UI Kit"

echo "Catalyst UI is a premium component library from Tailwind CSS."
echo "It includes 27 accessible React components (buttons, forms, dialogs, etc.)"
echo ""

has_tsx_files() {
  local src="$1"
  compgen -G "$src"/*.tsx >/dev/null 2>&1
}

resolve_catalyst_source() {
  local src="$1"
  if [[ -d "$src" ]] && has_tsx_files "$src"; then
    echo "$src"
    return 0
  fi
  if [[ -d "$src/typescript" ]] && has_tsx_files "$src/typescript"; then
    echo "$src/typescript"
    return 0
  fi
  return 1
}

if CATALYST_RESOLVED="$(resolve_catalyst_source "$CATALYST_SOURCE")"; then
  if [[ "$CATALYST_RESOLVED" != "$CATALYST_SOURCE" ]]; then
    echo "Adjusted Catalyst source to: $CATALYST_RESOLVED"
  fi
  CATALYST_SOURCE="$CATALYST_RESOLVED"
  echo "Catalyst source found at: $CATALYST_SOURCE"
  INCLUDE_CATALYST="y"
else
  echo "Catalyst source not found at: $CATALYST_SOURCE"
  echo "Set CATALYST_SOURCE to include: CATALYST_SOURCE=\"/path\" ./scripts/scaffold-frontend.sh"
  INCLUDE_CATALYST="n"
fi

################################################################################
# Step 7: Create frontend src directory structure
################################################################################

print_header "Step 7: Creating frontend src directory structure"

mkdir -p frontend/src/lib
mkdir -p frontend/src/schemas
mkdir -p frontend/src/services
mkdir -p frontend/src/hooks
mkdir -p frontend/src/types
mkdir -p frontend/src/pages
mkdir -p frontend/src/components

echo "Created frontend/src/{lib,schemas,services,hooks,types,pages,components}"

################################################################################
# Step 7a: Copy Catalyst UI Components (if enabled)
################################################################################

if [[ "$INCLUDE_CATALYST" =~ ^[Yy]$ ]]; then
  print_header "Step 7a: Copying Catalyst UI Components"

  # Copy all TypeScript component files
  cp "$CATALYST_SOURCE"/*.tsx frontend/src/components/

  CATALYST_COUNT=$(ls -1 frontend/src/components/*.tsx 2>/dev/null | wc -l | tr -d ' ')
  echo "Copied $CATALYST_COUNT Catalyst components to frontend/src/components/"

  # Replace link.tsx with TanStack Router integration
  cat > frontend/src/components/link.tsx << 'CATALYST_LINK_EOF'
import * as Headless from '@headlessui/react'
import { Link as TanStackLink, LinkProps } from '@tanstack/react-router'
import React, { forwardRef } from 'react'

export const Link = forwardRef(function Link(
  props: LinkProps & React.ComponentPropsWithoutRef<'a'>,
  ref: React.ForwardedRef<HTMLAnchorElement>
) {
  return (
    <Headless.DataInteractive>
      <TanStackLink {...props} ref={ref} />
    </Headless.DataInteractive>
  )
})
CATALYST_LINK_EOF

  echo "  Updated link.tsx for TanStack Router"
fi

################################################################################
# Step 8: Create lib/set-theme.ts
################################################################################

print_header "Step 8: Creating lib/set-theme.ts"

cat > frontend/src/lib/set-theme.ts << 'SET_THEME_EOF'
import { Theme } from '@/schemas/settings-schema'

export function setTheme(theme: Theme | undefined) {
  const root = window.document.documentElement
  root.classList.remove('light', 'dark')
  if (theme === 'light') {
    localStorage.setItem('theme', 'light')
    root.classList.add('light')
  } else if (theme === 'dark') {
    localStorage.setItem('theme', 'dark')
    root.classList.add('dark')
  } else {
    if (theme === 'system') localStorage.removeItem('theme')

    let systemTheme = window.matchMedia('(prefers-color-scheme: dark)').matches
      ? 'dark'
      : 'light'

    if (localStorage.getItem('theme') === 'light') systemTheme = 'light'
    if (localStorage.getItem('theme') === 'dark') systemTheme = 'dark'
    root.classList.add(systemTheme)
  }
}
SET_THEME_EOF

echo "Created frontend/src/lib/set-theme.ts"

################################################################################
# Step 9: Create schema files
################################################################################

print_header "Step 9: Creating schema files"

# pb-schema.ts
cat > frontend/src/schemas/pb-schema.ts << 'PB_SCHEMA_EOF'
import { z } from 'zod/v4'

export const pbIdSchema = z.string().regex(/^[a-z0-9]{15}$/)
export type PbId = z.infer<typeof pbIdSchema>

export const pbTokenSchema = z
  .string()
  .regex(/^[A-Za-z0-9_-]{2,}(?:\.[A-Za-z0-9_-]{2,}){2}$/, 'Invalid token')
PB_SCHEMA_EOF

echo "  Created pb-schema.ts"

# settings-schema.ts
cat > frontend/src/schemas/settings-schema.ts << 'SETTINGS_SCHEMA_EOF'
import { z } from 'zod/v4'
import { pbIdSchema } from './pb-schema'

export const themeSchema = z.enum(['system', 'light', 'dark'])

export type Theme = z.infer<typeof themeSchema>

export const settingsSchema = z.object({
  id: pbIdSchema,
  remindEmail: z.email('Invalid email'),
  remindByEmailEnabled: z.coerce.boolean(),
  theme: themeSchema
})

export type Settings = z.infer<typeof settingsSchema>
SETTINGS_SCHEMA_EOF

echo "  Created settings-schema.ts"

# user-schema.ts
cat > frontend/src/schemas/user-schema.ts << 'USER_SCHEMA_EOF'
import { z } from 'zod/v4'
import { pbIdSchema } from './pb-schema'
import { settingsSchema, themeSchema } from './settings-schema'

export const userSchema = z.object({
  id: pbIdSchema,
  avatar: z.string(),
  email: z.email('Invalid email'),
  name: z.string().min(2, 'Too short').optional().or(z.literal('')),
  verified: z.boolean(),
  authWithPasswordAvailable: z.boolean()
})

export type User = z.infer<typeof userSchema>

export const userWithSettingsSchema = userSchema.extend({
  authWithPasswordAvailable: z.boolean(),
  settings: settingsSchema
})

export type UserWithSettings = z.infer<typeof userWithSettingsSchema>

export const updateUserSettingsSchema = z
  .object({
    remindEmail: z.email('Invalid email'),
    remindByEmailEnabled: z.boolean(),
    avatar: z.instanceof(File).nullish().optional(),
    name: z.string().min(2, 'Too short').optional().or(z.literal('')),
    theme: themeSchema,
    oldPassword: z.string().optional(),
    password: z.string().optional(),
    passwordConfirm: z.string().optional()
  })
  .refine((data) => data.password === data.passwordConfirm, {
    message: 'Passwords must match',
    path: ['passwordConfirm']
  })
  .refine(
    (data) =>
      (data.oldPassword === '' && data.password === '') ||
      data.oldPassword !== data.password,
    {
      message: 'New password is the same',
      path: ['password']
    }
  )
  .refine(
    (data) => {
      const anyPasswordFieldNotEmpty =
        data.oldPassword || data.password || data.passwordConfirm
      const allPasswordFieldsFilled =
        data.oldPassword && data.password && data.passwordConfirm
      return !anyPasswordFieldNotEmpty || allPasswordFieldsFilled
    },
    {
      message: 'Complete all password fields',
      path: ['password']
    }
  )

export type UpdateUserSettingsFields = z.infer<typeof updateUserSettingsSchema>
USER_SCHEMA_EOF

echo "  Created user-schema.ts"

# auth-schema.ts
cat > frontend/src/schemas/auth-schema.ts << 'AUTH_SCHEMA_EOF'
import { z } from 'zod/v4'
import { pbTokenSchema } from './pb-schema'

export const loginSchema = z.object({
  email: z.email('Invalid email'),
  password: z.string().min(8, 'Invalid password')
})

export type LoginFields = z.infer<typeof loginSchema>

export const registerSchema = z
  .object({
    email: z.email('Invalid email'),
    name: z.string().min(2, 'Too short'),
    password: z.string().min(8, 'Too short'),
    passwordConfirm: z.string()
  })
  .refine((data) => data.password === data.passwordConfirm, {
    message: 'Passwords must match',
    path: ['passwordConfirm']
  })

export type RegisterFields = z.infer<typeof registerSchema>

export const verifyEmailSchema = z.object({
  token: pbTokenSchema
})

export const verifyEmailParamsSchema = z.object({
  token: pbTokenSchema.catch('').optional()
})

export type VerifyEmailFields = z.infer<typeof verifyEmailSchema>

export const forgotPasswordSchema = z.object({
  email: z.email('Invalid email')
})
export type ForgotPasswordFields = z.infer<typeof forgotPasswordSchema>

export const resetPasswordSchema = z
  .object({
    password: z.string().min(8, 'Too short'),
    passwordConfirm: z.string()
  })
  .refine((data) => data.password === data.passwordConfirm, {
    message: 'Passwords must match',
    path: ['passwordConfirm']
  })

export const resetPasswordParamsSchema = z.object({
  token: pbTokenSchema.catch('')
})

export type ResetPasswordFields = z.infer<typeof resetPasswordSchema>
AUTH_SCHEMA_EOF

echo "  Created auth-schema.ts"

################################################################################
# Step 10: Create types/pocketbase-types.ts
################################################################################

print_header "Step 10: Creating types/pocketbase-types.ts"

cat > frontend/src/types/pocketbase-types.ts << 'PB_TYPES_EOF'
/**
 * This file was @generated using pocketbase-typegen
 */

import type PocketBase from 'pocketbase'
import type { RecordService } from 'pocketbase'

export enum Collections {
  Settings = 'settings',
  Users = 'users'
}

// Alias types for improved usability
export type IsoDateString = string
export type RecordIdString = string
export type HTMLString = string

// System fields
export type BaseSystemFields<T = never> = {
  id: RecordIdString
  created: IsoDateString
  updated: IsoDateString
  collectionId: string
  collectionName: Collections
  expand?: T
}

export type AuthSystemFields<T = never> = {
  email: string
  emailVisibility: boolean
  username: string
  verified: boolean
} & BaseSystemFields<T>

// Record types for each collection

export enum SettingsThemeOptions {
  'system' = 'system',
  'light' = 'light',
  'dark' = 'dark'
}
export type SettingsRecord = {
  remindByEmailEnabled?: boolean
  remindEmail?: string
  theme?: SettingsThemeOptions
  user: RecordIdString
}

export type UsersRecord = {
  authWithPasswordAvailable?: boolean
  avatar?: string
  name?: string
}

// Response types include system fields and match responses from the PocketBase API
export type SettingsResponse<Texpand = unknown> = Required<SettingsRecord> &
  BaseSystemFields<Texpand>
export type UsersResponse<Texpand = unknown> = Required<UsersRecord> &
  AuthSystemFields<Texpand>

// Types containing all Records and Responses, useful for creating typing helper functions

export type CollectionRecords = {
  settings: SettingsRecord
  users: UsersRecord
}

export type CollectionResponses = {
  settings: SettingsResponse
  users: UsersResponse
}

// Type for usage with type asserted PocketBase instance
// https://github.com/pocketbase/js-sdk#specify-typescript-definitions

export type TypedPocketBase = PocketBase & {
  collection(idOrName: 'settings'): RecordService<SettingsResponse>
  collection(idOrName: 'users'): RecordService<UsersResponse>
}
PB_TYPES_EOF

echo "Created frontend/src/types/pocketbase-types.ts"

################################################################################
# Step 11: Create services
################################################################################

print_header "Step 11: Creating services"

# pocketbase.ts
cat > frontend/src/services/pocketbase.ts << 'POCKETBASE_SERVICE_EOF'
import { TypedPocketBase } from '@/types/pocketbase-types'
import PocketBase from 'pocketbase'

export const pb = new PocketBase() as TypedPocketBase
POCKETBASE_SERVICE_EOF

echo "  Created pocketbase.ts"

# api-auth.ts
cat > frontend/src/services/api-auth.ts << 'API_AUTH_EOF'
import { setTheme } from '@/lib/set-theme'
import { User, userSchema, userWithSettingsSchema } from '@/schemas/user-schema'
import { queryOptions } from '@tanstack/react-query'
import { pb } from './pocketbase'

export function checkUserIsLoggedIn() {
  return pb.authStore.isValid
}

export function checkEmailIsVerified() {
  return pb.authStore.record?.verified
}

export function checkVerifiedUserIsLoggedIn() {
  return checkUserIsLoggedIn() && checkEmailIsVerified()
}

export async function authRefresh() {
  if (!checkUserIsLoggedIn()) return
  await pb.collection('users').authRefresh({ requestKey: null })
}

export async function sendVerificationEmail(email: string) {
  await pb.collection('users').requestVerification(email)
}

export async function createNewUser(newUserData: {
  name: string
  email: string
  password: string
  passwordConfirm: string
}) {
  await pb.collection('users').create({ ...newUserData, emailVisibility: true })
  await sendVerificationEmail(newUserData.email)
}

export async function verifyEmailByToken(token: string) {
  await pb.collection('users').confirmVerification(token, { requestKey: null })
  if (pb.authStore.record) await authRefresh()
}

export async function loginWithPassword(email: string, password: string) {
  const authResult = await pb
    .collection('users')
    .authWithPassword(email, password)
  return authResult
}

export async function loginWithGoogle() {
  const authResult = await pb
    .collection('users')
    .authWithOAuth2({ provider: 'google' })
  await authRefresh()
  return authResult
}

export function logout() {
  pb.authStore.clear()
}

export async function requestPasswordReset(email: string) {
  await pb.collection('users').requestPasswordReset(email)
}

export async function confirmPasswordReset(
  password: string,
  passwordConfirm: string,
  token: string
) {
  await pb
    .collection('users')
    .confirmPasswordReset(token, password, passwordConfirm)
  if (pb.authStore.record)
    await loginWithPassword(pb.authStore.record.email, password)
}

export async function subscribeToUserChanges(
  userId: string,
  callback: (record: User) => void
) {
  try {
    pb.collection('users').subscribe(
      userId,
      (event) => {
        const userData = userSchema.parse(event.record)
        callback(userData)
      },
      {
        onError: (err: Error) =>
          console.error('Realtime user subscription error:', err)
      }
    )
  } catch (error) {
    console.error('Failed to subscribe to realtime user data:', error)
  }
}

export async function unsubscribeFromUserChanges() {
  pb.collection('users').unsubscribe('*')
}

export const userQueryOptions = queryOptions({
  queryKey: ['user'],
  queryFn: async () => {
    if (!checkUserIsLoggedIn()) return null

    try {
      await authRefresh()
    } catch {
      logout()
      return null
    }

    const settings = await pb
      .collection('settings')
      .getFirstListItem(`user="${pb.authStore.record?.id}"`)

    setTheme(settings.theme)

    const userData = userWithSettingsSchema.parse({
      ...pb.authStore.record,
      settings
    })

    return userData
  },
  staleTime: 5 * 60 * 1000,
  gcTime: 30 * 60 * 1000,
  refetchInterval: false
})
API_AUTH_EOF

echo "  Created api-auth.ts"

# api-settings.ts
cat > frontend/src/services/api-settings.ts << 'API_SETTINGS_EOF'
import { UpdateUserSettingsFields } from '@/schemas/user-schema'
import { loginWithPassword } from './api-auth'
import { pb } from './pocketbase'

export async function getSettings(userId?: string) {
  userId ??= pb.authStore.record?.id

  const settings = await pb
    .collection('settings')
    .getFirstListItem(`user="${userId}"`)

  if (!settings) throw new Error('Could not fetch settings data')

  return settings
}

export async function updateUserSettings(
  userId: string,
  formData: UpdateUserSettingsFields
) {
  const {
    remindEmail,
    remindByEmailEnabled,
    theme,
    name,
    avatar,
    oldPassword,
    password,
    passwordConfirm
  } = formData
  const userIsChangingPassword = oldPassword && password && passwordConfirm

  const newUserData = await pb
    .collection('users')
    .update(
      userId,
      userIsChangingPassword
        ? { name, avatar, oldPassword, password, passwordConfirm }
        : { name, avatar }
    )

  userIsChangingPassword &&
    (await loginWithPassword(newUserData.email, password))

  const settings = await pb
    .collection('settings')
    .getFirstListItem(`user="${newUserData.id}"`)

  settings &&
    (await pb.collection('settings').update(settings.id, {
      remindEmail,
      remindByEmailEnabled,
      theme
    }))
}
API_SETTINGS_EOF

echo "  Created api-settings.ts"

################################################################################
# Step 12: Create hooks
################################################################################

print_header "Step 12: Creating hooks"

# use-auth.ts (simplified - no toast calls)
cat > frontend/src/hooks/use-auth.ts << 'USE_AUTH_EOF'
import { RegisterFields } from '@/schemas/auth-schema'
import { User, UserWithSettings } from '@/schemas/user-schema'
import {
  authRefresh,
  confirmPasswordReset as confirmPasswordResetApi,
  createNewUser,
  loginWithGoogle as loginWithGoogleApi,
  loginWithPassword as loginWithPasswordApi,
  logout as logoutApi,
  requestPasswordReset as requestPasswordResetApi,
  sendVerificationEmail as sendVerificationEmailApi,
  subscribeToUserChanges,
  unsubscribeFromUserChanges,
  userQueryOptions,
  verifyEmailByToken as verifyEmailByTokenApi
} from '@/services/api-auth'
import { useQueryClient, useSuspenseQuery } from '@tanstack/react-query'
import { useRouter } from '@tanstack/react-router'
import { useState } from 'react'

export default function useAuth() {
  const [emailSendCountdown, setEmailSendCountdown] = useState(0)
  const router = useRouter()
  const queryClient = useQueryClient()

  const { data: user } = useSuspenseQuery(userQueryOptions)

  const logout = () => {
    logoutApi()
    queryClient.clear()
    unsubscribeFromUserChanges()
    router.navigate({ to: '/' })
  }

  const subscribeUserChangeCallback = async (record: User) => {
    await authRefresh()
    router.invalidate()
    queryClient.setQueryData(['user'], record)
  }

  const loginWithPassword = async (email: string, password: string) => {
    const authResult = await loginWithPasswordApi(email, password)
    subscribeToUserChanges(authResult.record.id, subscribeUserChangeCallback)
    queryClient.invalidateQueries({ queryKey: ['user'] })
    router.navigate({ to: '/dashboard' })
    return authResult
  }

  const loginWithGoogle = async () => {
    const authResult = await loginWithGoogleApi()
    subscribeToUserChanges(authResult.record.id, subscribeUserChangeCallback)
    queryClient.invalidateQueries({ queryKey: ['user'] })
    router.invalidate()
    router.navigate({ to: '/dashboard' })
    return authResult
  }

  const register = async (newUserData: RegisterFields) => {
    await createNewUser(newUserData)
    // User should implement their own success notification
    router.navigate({ to: '/' })
  }

  const startEmailSendCountdown = ({
    resetTargetTime = true
  }: {
    resetTargetTime?: boolean
  } = {}) => {
    let targetTime = parseInt(localStorage.getItem('sendEmailTimeout') || '')
    if (resetTargetTime && !targetTime) {
      targetTime = Date.now() + 60 * 1000
      localStorage.setItem('sendEmailTimeout', targetTime.toString())
    }

    const ticker = setInterval(() => {
      const secondsRemaining = Math.ceil((targetTime - Date.now()) / 1000)
      if (secondsRemaining > 0) {
        setEmailSendCountdown(secondsRemaining)
      } else {
        setEmailSendCountdown(0)
        localStorage.removeItem('sendEmailTimeout')
        clearInterval(ticker)
      }
    })
  }

  const requestPasswordReset = async (email: string) => {
    await requestPasswordResetApi(email)
    startEmailSendCountdown()
  }

  const confirmPasswordReset = async (
    password: string,
    passwordConfirm: string,
    token: string
  ) => {
    await confirmPasswordResetApi(password, passwordConfirm, token)
    router.navigate({ to: '/' })
  }

  const sendVerificationEmail = async (email: string | undefined) => {
    if (!email) throw new Error("Unable to get logged in user's email")
    await sendVerificationEmailApi(email)
    startEmailSendCountdown()
  }

  const verifyEmailByToken = async (token: string) => {
    await verifyEmailByTokenApi(token)
    queryClient.setQueryData(['user'], (userData: UserWithSettings) =>
      userData
        ? {
            ...userData,
            verified: true
          }
        : userData
    )
    router.navigate({ to: '/' })
  }

  return {
    user,
    logout,
    loginWithPassword,
    loginWithGoogle,
    register,
    requestPasswordReset,
    confirmPasswordReset,
    sendVerificationEmail,
    verifyEmailByToken,
    startEmailSendCountdown,
    emailSendCountdown
  }
}
USE_AUTH_EOF

echo "  Created use-auth.ts"

# use-settings.ts (simplified - no toast calls)
cat > frontend/src/hooks/use-settings.ts << 'USE_SETTINGS_EOF'
import { UpdateUserSettingsFields } from '@/schemas/user-schema'
import { userQueryOptions } from '@/services/api-auth'
import { updateUserSettings } from '@/services/api-settings'
import {
  useMutation,
  useQueryClient,
  useSuspenseQuery
} from '@tanstack/react-query'
import { useNavigate } from '@tanstack/react-router'

export default function useSettings() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { data, isLoading } = useSuspenseQuery(userQueryOptions)

  const { name, id: userId, settings, authWithPasswordAvailable } = data ?? {}
  const remindEmail = settings?.remindEmail ?? ''
  const remindByEmailEnabled = settings?.remindByEmailEnabled
  const theme = settings?.theme || 'system'

  const updateSettingsMutation = useMutation({
    mutationFn: ({
      userId,
      data
    }: {
      userId: string
      data: UpdateUserSettingsFields
    }) => updateUserSettings(userId, data),

    onMutate: async (newData) => {
      await queryClient.cancelQueries({ queryKey: ['user'] })
      const previousUser = queryClient.getQueryData(['user'])

      queryClient.setQueryData(['user'], (currentUser: any) => ({
        ...currentUser,
        name: newData.data.name,
        settings: {
          ...currentUser.settings,
          theme: newData.data.theme,
          remindEmail: newData.data.remindEmail,
          remindByEmailEnabled: newData.data.remindByEmailEnabled
        }
      }))

      return { previousUser }
    },

    onSuccess: () => {
      // User should implement their own success notification
      navigate({ to: '/dashboard' })
    },

    onError: (error, _, context) => {
      console.error('Failed to update settings:', error)
      queryClient.setQueryData(['user'], context?.previousUser)
    },

    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['user'] })
    }
  })

  const updateSettings = (userId: string, userData: UpdateUserSettingsFields) =>
    updateSettingsMutation.mutate({ userId, data: userData })

  return {
    userId,
    name,
    remindEmail,
    remindByEmailEnabled,
    theme,
    authWithPasswordAvailable,
    isLoading,
    updateSettings
  }
}
USE_SETTINGS_EOF

echo "  Created use-settings.ts"

################################################################################
# Step 13: Create router.tsx
################################################################################

print_header "Step 13: Creating router.tsx"

cat > frontend/src/router.tsx << 'ROUTER_EOF'
import RootLayout from '@/root-layout'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ReactQueryDevtools } from '@tanstack/react-query-devtools'
import {
  createRootRouteWithContext,
  createRoute,
  createRouter,
  redirect,
  RouterProvider
} from '@tanstack/react-router'
import { TanStackRouterDevtools } from '@tanstack/react-router-devtools'
import { setTheme } from './lib/set-theme'
import DashboardPage from './pages/dashboard'
import ErrorPage from './pages/error'
import HomePage from './pages/home'
import NotFoundPage from './pages/not-found'
import { checkVerifiedUserIsLoggedIn, userQueryOptions } from './services/api-auth'

interface RootContext {
  queryClient: QueryClient
}

const rootRoute = createRootRouteWithContext<RootContext>()({
  component: RootLayout,
  notFoundComponent: NotFoundPage,
  errorComponent: ErrorPage,
  loader: ({ context: { queryClient } }) =>
    queryClient.ensureQueryData(userQueryOptions),
  beforeLoad: async ({ context: { queryClient } }) => {
    const user = queryClient.getQueryData(userQueryOptions.queryKey)
    setTheme(user?.settings?.theme)
  }
})

const homeRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/',
  component: HomePage,
  beforeLoad: async () => {
    // Redirect logged-in users to dashboard
    if (checkVerifiedUserIsLoggedIn()) throw redirect({ to: '/dashboard' })
  }
})

const dashboardRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: 'dashboard',
  component: DashboardPage,
  beforeLoad: () => {
    // Protected route - redirect to home if not logged in
    if (!checkVerifiedUserIsLoggedIn()) throw redirect({ to: '/' })
  }
})

const routeTree = rootRoute.addChildren([homeRoute, dashboardRoute])
const queryClient = new QueryClient()

const router = createRouter({
  routeTree,
  defaultPreload: 'intent',
  scrollRestoration: true,
  context: { queryClient }
})

declare module '@tanstack/react-router' {
  interface Register {
    router: typeof router
  }
}

export default function Router({ devToolsEnabled }: { devToolsEnabled?: boolean }) {
  devToolsEnabled ??= process.env.NODE_ENV === 'development'

  return (
    <QueryClientProvider client={queryClient}>
      <RouterProvider router={router} />
      {devToolsEnabled && (
        <>
          <ReactQueryDevtools initialIsOpen={false} buttonPosition='bottom-left' />
          <TanStackRouterDevtools router={router} position='bottom-right' />
        </>
      )}
    </QueryClientProvider>
  )
}
ROUTER_EOF

echo "Created frontend/src/router.tsx"

################################################################################
# Step 14: Create root-layout.tsx
################################################################################

print_header "Step 14: Creating root-layout.tsx"

cat > frontend/src/root-layout.tsx << 'ROOT_LAYOUT_EOF'
import { Outlet } from '@tanstack/react-router'

export default function RootLayout() {
  return (
    <div className='mx-auto flex min-h-dvh max-w-[800px] flex-col gap-4 px-4 py-2'>
      <Outlet />
    </div>
  )
}
ROOT_LAYOUT_EOF

echo "Created frontend/src/root-layout.tsx"

################################################################################
# Step 15: Create pages
################################################################################

print_header "Step 15: Creating pages"

# home.tsx
cat > frontend/src/pages/home.tsx << 'HOME_PAGE_EOF'
export default function HomePage() {
  return (
    <main>
      <h1>Welcome</h1>
      <p>Your app home page. Build your login/register UI here.</p>
    </main>
  )
}
HOME_PAGE_EOF

echo "  Created home.tsx"

# dashboard.tsx (protected example)
cat > frontend/src/pages/dashboard.tsx << 'DASHBOARD_PAGE_EOF'
import useAuth from '@/hooks/use-auth'

export default function DashboardPage() {
  const { user, logout } = useAuth()

  return (
    <main>
      <h1>Dashboard</h1>
      <p>Welcome, {user?.name || user?.email}</p>
      <button onClick={logout}>Logout</button>
    </main>
  )
}
DASHBOARD_PAGE_EOF

echo "  Created dashboard.tsx"

# error.tsx
cat > frontend/src/pages/error.tsx << 'ERROR_PAGE_EOF'
import type { ErrorComponentProps } from '@tanstack/react-router'

export default function ErrorPage({ error }: ErrorComponentProps) {
  const message = error instanceof Error ? error.message : 'Unknown error'

  return (
    <main>
      <h1>Something went wrong</h1>
      <pre>{message}</pre>
    </main>
  )
}
ERROR_PAGE_EOF

echo "  Created error.tsx"

# not-found.tsx
cat > frontend/src/pages/not-found.tsx << 'NOT_FOUND_PAGE_EOF'
export default function NotFoundPage() {
  return (
    <main>
      <h1>404 - Page Not Found</h1>
    </main>
  )
}
NOT_FOUND_PAGE_EOF

echo "  Created not-found.tsx"

################################################################################
# Step 16: Create root.tsx entry file
################################################################################

print_header "Step 16: Creating root.tsx entry file"

cat > frontend/src/root.tsx << 'ROOT_EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import Router from './router'
import './index.css'

const rootEl = document.getElementById('root')
if (!rootEl) throw new Error('The #root HTML element is missing from the DOM')

ReactDOM.createRoot(rootEl).render(
  <React.StrictMode>
    <Router />
  </React.StrictMode>
)
ROOT_EOF

echo "Created frontend/src/root.tsx"

################################################################################
# Step 17: Update index.html script reference
################################################################################

print_header "Step 17: Updating index.html script reference"

sed -i.bak 's|/src/main.tsx|/src/root.tsx|g' frontend/index.html
rm -f frontend/index.html.bak

echo "Updated frontend/index.html to use /src/root.tsx"

################################################################################
# Step 18: Cleanup Vite template files
################################################################################

print_header "Step 18: Cleaning up Vite template files"

rm -f frontend/src/App.tsx
rm -f frontend/src/App.css
rm -f frontend/src/main.tsx

echo "Removed App.tsx, App.css, and main.tsx (replaced by root.tsx and router)"

################################################################################
# Step 19: Update backend/go.mod and Go import paths
################################################################################

print_header "Step 19: Updating backend/go.mod and Go imports"

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
# Step 20: Update Dockerfile
################################################################################

print_header "Step 20: Updating Dockerfile"

sed -i.bak "s|go build -tags production -o saas-template|go build -tags production -o $PROJECT_NAME|g" Dockerfile
sed -i.bak "s|COPY --from=builder-go /app/saas-template|COPY --from=builder-go /app/$PROJECT_NAME|g" Dockerfile
sed -i.bak "s|\"/app/saas-template\"|\"/app/$PROJECT_NAME\"|g" Dockerfile
rm -f Dockerfile.bak

echo "Updated Dockerfile binary references"

################################################################################
# Step 21: Update docker-compose.yml
################################################################################

print_header "Step 21: Updating docker-compose.yml"

sed -i.bak "s|saas-template:|$PROJECT_NAME:|g" docker-compose.yml
sed -i.bak "s|container_name: saas-template|container_name: $PROJECT_NAME|g" docker-compose.yml
rm -f docker-compose.yml.bak

echo "Updated docker-compose.yml service and container names"

################################################################################
# Step 22: Update fly.toml
################################################################################

print_header "Step 22: Updating fly.toml"

sed -i.bak "s|^app = \"saas-template\"|app = \"$PROJECT_NAME\"|g" fly.toml
rm -f fly.toml.bak

echo "Updated fly.toml app name to: $PROJECT_NAME"

################################################################################
# Step 23: Remove template-specific GitHub files
################################################################################

print_header "Step 23: Removing template-specific GitHub files"

# Remove sync-dependencies workflow and scripts (only relevant to saas-template repo)
rm -f .github/workflows/sync-dependencies.yml
rm -f .github/scripts/sync-dependencies.sh
rm -f .github/scripts/generate-pr-description.sh

# Clean up empty directories if scripts folder is now empty
if [ -d ".github/scripts" ] && [ -z "$(ls -A .github/scripts 2>/dev/null)" ]; then
  rmdir .github/scripts
  echo "Removed empty .github/scripts directory"
fi

# Clean up empty workflows directory if now empty
if [ -d ".github/workflows" ] && [ -z "$(ls -A .github/workflows 2>/dev/null)" ]; then
  rmdir .github/workflows
  echo "Removed empty .github/workflows directory"
fi

# Clean up empty .github directory if now empty
if [ -d ".github" ] && [ -z "$(ls -A .github 2>/dev/null)" ]; then
  rmdir .github
  echo "Removed empty .github directory"
fi

echo "Removed template-specific GitHub files:"
echo "  - .github/workflows/sync-dependencies.yml"
echo "  - .github/scripts/sync-dependencies.sh"
echo "  - .github/scripts/generate-pr-description.sh"

################################################################################
# Step 24: Cleanup
################################################################################

print_header "Step 24: Cleanup"

# Remove root index.html if it exists
if [[ -f "index.html" ]]; then
  rm -f index.html
  echo "Removed root index.html"
else
  echo "No root index.html to remove"
fi

################################################################################
# Step 25: Run npm install
################################################################################

print_header "Step 25: Installing Dependencies"

npm install

echo "Dependencies installed"

################################################################################
# Step 26: Remove template-specific files
################################################################################

print_header "Step 26: Removing template-specific files"

rm -f NEW_PROJECT_PLAN.md
rm -f CLAUDE.md
rm -f README.md
echo "Removed: NEW_PROJECT_PLAN.md, CLAUDE.md, README.md"

################################################################################
# Step 27: Fresh git history
################################################################################

print_header "Step 27: Initializing fresh git repository"

# Remove existing git history
rm -rf .git

# Initialize new repository
git init -q

# Create initial commit
git add .
git commit -q -m "Initial commit

Scaffolded from saas-template
Project: $PROJECT_NAME
Module: $GO_MODULE"

echo "Fresh git repository initialized with initial commit"

################################################################################
# Post-setup guidance
################################################################################

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    Scaffold Complete!                          ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║  Project: $PROJECT_NAME"
echo "║  Location: $(pwd)"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║  Next steps:                                                   ║"
echo "║    1. Create GitHub repo: gh repo create $PROJECT_NAME        ║"
echo "║    2. git remote add origin <your-repo-url>                   ║"
echo "║    3. git push -u origin main                                 ║"
echo "║    4. npm run dev                                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
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
echo "What's included:"
echo ""
echo "  - TanStack Router with auth guards (/ public, /dashboard protected)"
echo "  - TanStack Query with userQueryOptions for user data"
echo "  - PocketBase typed client (pb export)"
echo "  - Auth hook (useAuth: login, logout, register, password reset)"
echo "  - Settings hook (useSettings: with optimistic updates)"
echo "  - Zod schemas for validation (auth, user, settings)"
echo "  - Theme management (light/dark/system)"

if [[ "$INCLUDE_CATALYST" =~ ^[Yy]$ ]]; then
  echo ""
  echo "Catalyst UI Components:"
  echo "  - $CATALYST_COUNT components in frontend/src/components/"
  echo "  - Import: import { Button } from '@/components/button'"
  echo "  - Docs: https://catalyst.tailwindui.com/docs"
fi

echo ""
echo "Build your login/register UI in frontend/src/pages/home.tsx"
echo ""

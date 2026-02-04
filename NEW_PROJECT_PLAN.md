# New Project Plan: Stock Vite React Frontend + Embedded Go Backend

This document describes how to create a new project from this SaaS template. The
scaffold script automates most of the setup, leaving only branding and deployment
configuration as manual steps.

## Table of Contents

- [Goals](#goals)
- [Prerequisites](#prerequisites)
- [Quick Start (Automated)](#quick-start-automated)
- [What the Script Does](#what-the-script-does)
- [Manual Steps After Scaffolding](#manual-steps-after-scaffolding)
- [Verification](#verification)
- [Reference: Configuration Files](#reference-configuration-files)
- [Reference: Environment Variables](#reference-environment-variables)
- [Reference: Project Structure](#reference-project-structure)
- [Manual Setup (Alternative)](#manual-setup-alternative)
- [Future Improvements](#future-improvements)

---

## Goals

- **Fresh frontend**: Replace the existing UI with the official Vite React-TS template
- **Keep backend unchanged**: PocketBase + Go embed workflow stays the same
- **Works out of the box**: Scaffolded app runs immediately with HMR
- **Enhanced DX**: ESLint, Prettier, and TypeScript configured for React development
- **Single binary deploy**: Frontend embeds into Go binary for production
- **QoL features included**: TanStack Router + Query, PocketBase typed client, auth services/hooks, settings services/hooks, Zod schemas
- **Catalyst UI Kit included**: Premium accessible component library integration (always enabled)

---

## Prerequisites

Before running the scaffold script, ensure you have:

| Tool | Version | Check Command | Install |
|------|---------|---------------|---------|
| Node.js | 18+ | `node --version` | [nodejs.org](https://nodejs.org) |
| npm | 9+ | `npm --version` | Comes with Node.js |
| Go | 1.21+ | `go version` | [go.dev](https://go.dev) |
| jq | 1.6+ | `jq --version` | `brew install jq` (macOS) |

---

## Quick Start (Automated)

### 1. Clone the Template

First, clone this repository with your desired project name:

```bash
# Clone with your project name
git clone https://github.com/mauriceLC92/saas-template your-project-name
cd your-project-name
```

**Important:** The directory name you choose during cloning will be your workspace. The scaffold script operates in-place and does NOT rename folders.

### 2. Run the Scaffold Script

The scaffold script automates the entire setup process:

```bash
# From the project directory
# Catalyst UI components are required
CATALYST_SOURCE=/path/to/catalyst/typescript ./scripts/scaffold-frontend.sh
```

The script will prompt you for:

1. **Project name** (e.g., `my-saas-app`)
   - Used for: package.json name, binary name, Docker service/container names
   - Format: letters, numbers, hyphens, underscores (must start with letter)

2. **Go module path** (e.g., `github.com/username/my-saas-app`)
   - Used for: backend/go.mod module declaration
   - Format: `domain/org/project`

3. **Catalyst UI Kit** (always included)
   - Requires `CATALYST_SOURCE` to be set
   - Adds @headlessui/react, framer-motion, and clsx

After confirmation, the script runs automatically and installs dependencies at the end.

---

## What the Script Does

The scaffold script performs these steps in order (27 total steps):

**Note:** The script operates in-place on your cloned directory. It does NOT rename or move your project folder.

### Step 1: Scaffold Vite React-TS Frontend

- Creates temporary directory
- Runs `npm create vite@latest --no-install` with `react-ts` template
- Copies only `index.html`, `public/`, and `src/` to `frontend/`
- Template config files are discarded (we use root-level configs)

### Step 2: Update vite.config.ts

Replaces with minimal config:
- `root: 'frontend'` - Vite looks in frontend/ for source
- `plugins: [react(), tailwindcss()]` - React + Tailwind CSS v4 via `@tailwindcss/vite`
- `build.outDir: '../backend/dist'` - Output for Go embed
- `@` path alias - Import from `@/components/...`
- `/api` proxy - Routes API calls to backend during dev

### Step 3: Update package.json

- Sets project name from your input
- **Merges dependencies**: Vite template deps + extra dev tooling
- Updates scripts with your binary name (`build:server`, `preview`)
- Adds Catalyst dependencies (always enabled)

**Dependency strategy:**
- Vite template dependencies are preserved (app works out of the box)
- Extra production dependencies are merged in:
  - `@heroicons/react` - SVG icon library from the makers of Tailwind CSS
  - `@tanstack/react-query` - Server state management
  - `@tanstack/react-router` - Type-safe file-based routing
  - `pocketbase` - PocketBase JavaScript SDK
  - `zod` - Runtime type validation for schemas
  - `@headlessui/react` - Catalyst UI Kit
  - `framer-motion` - Catalyst animation library
  - `clsx` - Catalyst utility for className management
- Extra dev dependencies are merged in:
  - `@tailwindcss/vite` - Tailwind CSS v4 Vite plugin
  - `tailwindcss` - Tailwind CSS v4
  - `tailwind-merge` - Utility for merging Tailwind classes (used by Catalyst)
  - `@tanstack/react-query-devtools` - Query devtools
  - `@tanstack/react-router-devtools` - Router devtools
  - `@typescript-eslint/*` - TypeScript linting
  - `eslint-plugin-react*` - React-specific rules
  - `eslint-config-prettier` - Prettier integration
  - `prettier` - Code formatting
  - `globals` - Browser globals for ESLint

### Step 4: Update eslint.config.mjs

Replaces with minimal flat config:
- TypeScript parser and plugin
- React, React Hooks, React Refresh plugins
- Prettier integration (disables conflicting rules)
- Targets `frontend/src/**/*.{ts,tsx}`

### Step 5: Update .prettierrc.json

Replaces with minimal config:
- No Tailwind plugin (add back if using Tailwind)
- Consistent formatting: single quotes, no semicolons, 80 char width

### Step 6: Update tsconfig.json

Replaces with full config:
- ESNext target with React JSX
- Strict mode enabled
- `@/*` path alias matching vite.config.ts
- Includes only `frontend/src`

### Catalyst UI Kit (Required)

The script requires the `CATALYST_SOURCE` environment variable to include the Catalyst UI component library. This premium accessible component library provides production-ready components built with Tailwind CSS and HeadlessUI.

**What you'll be asked:**
- Confirmation of the `CATALYST_SOURCE` path
- Dependencies (`@headlessui/react`, `framer-motion`, `clsx`) are automatically added

**Step 7a: Copy Catalyst UI Components**
- Copies pre-built Catalyst components from the provided source directory
- Creates `frontend/src/components/` directory with all UI components
- Includes buttons, forms, dialogs, tabs, and other common components
- All components are fully typed and ready to use

### Steps 7-18: Create Frontend QoL Features

The scaffold creates a complete frontend foundation:

**Step 7: Directory structure**
- Creates `lib/`, `schemas/`, `services/`, `hooks/`, `types/`, `pages/`

**Step 8: lib/set-theme.ts**
- Theme management utility (light/dark/system)
- Required by userQueryOptions for auto-applying user theme preference

**Step 9: Schema files**
- `pb-schema.ts` - PocketBase ID and token validation
- `settings-schema.ts` - User settings with theme enum
- `user-schema.ts` - User data and update validation
- `auth-schema.ts` - Login, register, password reset validation

**Step 10: types/pocketbase-types.ts**
- TypedPocketBase type for collection-aware SDK
- Settings and Users collection types

**Step 11: Services**
- `pocketbase.ts` - Typed PocketBase client export
- `api-auth.ts` - Complete auth API (login, register, verify, password reset, real-time subscriptions)
- `api-settings.ts` - Settings CRUD operations

**Step 12: Hooks (simplified - no toast calls)**
- `use-auth.ts` - Auth state, login/logout/register functions
- `use-settings.ts` - Settings state with optimistic updates

**Step 13: router.tsx**
- TanStack Router setup with QueryClient integration
- Root route with user data pre-loading and theme application
- Home route (/) - public, redirects logged-in users to /dashboard
- Dashboard route (/dashboard) - protected, redirects unauthenticated to /
- Devtools included for development

**Step 14: root-layout.tsx**
- Minimal layout wrapper with centered content

**Step 15: Pages**
- `home.tsx` - Public landing page placeholder
- `dashboard.tsx` - Protected example with logout button
- `error.tsx` - Error boundary page
- `not-found.tsx` - 404 page

**Step 16: root.tsx**
- Entry point that mounts Router component

**Step 17: Update index.html**
- Changes script src from `/src/main.tsx` to `/src/root.tsx`

**Step 18: Cleanup**
- Removes Vite template files (App.tsx, App.css, main.tsx)
- Creates clean `index.css` with only `@import "tailwindcss";` (replaces Vite template styles)

### Step 19: Update backend/go.mod and Go Imports

- Extracts the old module path from `go.mod`
- Replaces module path on line 1 with your Go module path
- Finds all `.go` files that import from the old module
- Updates import statements to use the new module path
- Other dependencies in `go.sum` remain unchanged

### Step 20: Update Dockerfile

Replaces `saas-template` with your project name in:
- Build output: `go build -o YOUR_PROJECT`
- Copy command: `COPY --from=builder-go /app/YOUR_PROJECT`
- CMD: `CMD ["/app/YOUR_PROJECT", "serve", ...]`

### Step 21: Update docker-compose.yml

Replaces `saas-template` with your project name:
- Service name
- Container name

### Step 22: Update fly.toml

Updates the Fly.io configuration with your project name:
- `app = "saas-template"` → `app = "your-project-name"`

### Step 23: Remove Template-Specific GitHub Files

Removes GitHub workflow and scripts that are only relevant to the template repo:
- `.github/workflows/sync-dependencies.yml` - Syncs deps from upstream repo
- `.github/scripts/sync-dependencies.sh` - Sync implementation script
- `.github/scripts/generate-pr-description.sh` - PR description generator

Also cleans up empty `.github/` directories after removal.

### Step 24: Cleanup

- Removes root `index.html` if it exists (old UI entry point)
- The new entry point is `frontend/index.html`

### Step 25: Install Dependencies

- Runs `npm install` once after package.json merge and Catalyst copy
- You're ready to start development

---

## Manual Steps After Scaffolding

These steps require your input and cannot be automated:

### 1. Update Email Template Branding

Files in `backend/templates/`:

| File | What to Update |
|------|----------------|
| `base.layout.gohtml` | Company name in header/footer, meta tags |
| `styles.partial.gohtml` | Brand colors, fonts |
| `verify-email.page.gohtml` | Email verification subject and copy |
| `reset-password.page.gohtml` | Password reset subject and copy |
| `auth-alert.page.gohtml` | Login alert subject and copy |
| `tasks.page.gohtml` | Rename or remove if not using tasks feature |

### 2. Update Sender Email

In `backend/notifier/email.go`, update the From address:

```go
// Change from
From: "noreply@saas-template.com"
// To
From: "noreply@yourdomain.com"
```

### 3. Update .gitignore

Add your binary name and standard ignores:

```gitignore
# Dependencies
node_modules/

# Build outputs
backend/dist/
YOUR_PROJECT_NAME
*.exe

# Database
db/
*.db

# Environment
.env
.env.local

# IDE
.idea/
.vscode/
*.swp

# OS
.DS_Store
Thumbs.db
```

### 4. Create PocketBase Superuser

After first run, create an admin user:

```bash
./YOUR_PROJECT_NAME superuser upsert admin@example.com yourpassword
```

Then access the admin dashboard at `http://localhost:8090/_/`

### 5. Import Database Schema (Optional)

If you want the default collections (users, tasks, settings):

1. Open `http://localhost:8090/_/`
2. Go to Settings → Import Collections
3. Import `backend/pb_schema.json`

For a clean start, skip this and define your own collections.

---

## Verification

After scaffolding, verify everything works:

```bash
# Start development servers
npm run dev
# Frontend: http://localhost:5173 (with HMR)
# Backend:  http://localhost:8090 (PocketBase)

# Build for production
npm run build
# Creates: backend/dist/ (frontend assets)
# Creates: ./YOUR_PROJECT_NAME (Go binary)

# Run production build
npm run preview
# Serves embedded frontend from Go binary

# Lint and format
npm run lint    # TypeScript + ESLint
npm run pretty  # Prettier
```

---

## Reference: Configuration Files

### vite.config.ts

```ts
import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import path from 'node:path'
import { defineConfig, loadEnv } from 'vite'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const backendUrl = env.VITE_BACKEND_URL || 'http://localhost:8090'

  return {
    root: 'frontend',
    plugins: [react(), tailwindcss()],
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
```

### eslint.config.mjs

```js
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
```

### .prettierrc.json

```json
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
```

### tsconfig.json

```json
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
```

---

## Reference: Environment Variables

| Variable | Purpose | Default | Used By |
|----------|---------|---------|---------|
| `VITE_BACKEND_URL` | Backend URL for dev proxy | `http://localhost:8090` | Vite |
| `VITE_DOMAIN` | Domain injected at build | - | Vite/Docker |
| `DOMAIN_NAME` | Docker build arg for domain | - | Dockerfile |
| `DB_DIR` | SQLite database directory | `db` | Backend |
| `MAILER_CRON_SCHEDULE` | Email notification cron | `0 9 * * *` (9 AM daily) | Backend |
| `MAILER_NUM_WORKERS` | Email worker pool size | `10` | Backend |

---

## Reference: Project Structure

After scaffolding, your project structure will be:

```
your-project/
├── backend/
│   ├── dist/              # Frontend build output (git-ignored)
│   ├── notifier/          # Email notification system
│   ├── templates/         # Go HTML email templates
│   ├── go.mod             # Go module (updated with your path)
│   ├── go.sum
│   ├── main.go            # PocketBase entry point
│   ├── auth.go            # Auth hooks and middleware
│   ├── mailer.go          # Email worker pool
│   └── pb_schema.json     # Default PocketBase schema
├── frontend/
│   ├── public/            # Static assets
│   ├── src/
│   │   ├── components/    # Catalyst UI components
│   │   ├── hooks/
│   │   │   ├── use-auth.ts       # Auth hook (login, logout, register, etc.)
│   │   │   └── use-settings.ts   # Settings hook with optimistic updates
│   │   ├── lib/
│   │   │   └── set-theme.ts      # Theme management utility
│   │   ├── pages/
│   │   │   ├── dashboard.tsx     # Protected route example
│   │   │   ├── error.tsx         # Error boundary page
│   │   │   ├── home.tsx          # Public landing page
│   │   │   └── not-found.tsx     # 404 page
│   │   ├── schemas/
│   │   │   ├── auth-schema.ts    # Login, register, password reset validation
│   │   │   ├── pb-schema.ts      # PocketBase ID/token types
│   │   │   ├── settings-schema.ts # Settings validation
│   │   │   └── user-schema.ts    # User data validation
│   │   ├── services/
│   │   │   ├── api-auth.ts       # Auth API + userQueryOptions
│   │   │   ├── api-settings.ts   # Settings CRUD
│   │   │   └── pocketbase.ts     # Typed PocketBase client
│   │   ├── types/
│   │   │   └── pocketbase-types.ts # TypedPocketBase definitions
│   │   ├── index.css             # Tailwind CSS import
│   │   ├── root.tsx              # Entry point (mounts Router)
│   │   ├── root-layout.tsx       # App layout wrapper
│   │   └── router.tsx            # TanStack Router setup
│   └── index.html                # HTML entry point
├── db/                    # SQLite database (git-ignored)
├── scripts/
│   └── scaffold-frontend.sh
├── .prettierrc.json
├── docker-compose.yml
├── Dockerfile
├── eslint.config.mjs
├── package.json
├── tsconfig.json
├── vite.config.ts
└── YOUR_PROJECT_NAME      # Built binary (git-ignored)
```

---

## Manual Setup (Alternative)

If you prefer not to use the script, or need to understand what it does:

### 1. Copy Required Files

From this repo to your new repo:
- `backend/` (exclude `backend/dist/`)
- `Dockerfile`
- `docker-compose.yml`
- `fly.toml` (optional, for Fly.io deployment)

### 2. Scaffold Vite Frontend

```bash
npm create vite@latest frontend -- --template react-ts --no-interactive --no-install
```

Use `--no-interactive` to prevent prompts and `--no-install` to prevent auto-installation. This keeps the install step aligned with the package.json merge.

Then remove the config files from `frontend/` (we use root-level configs):
- `frontend/vite.config.ts`
- `frontend/tsconfig*.json`
- `frontend/eslint.config.js`
- `frontend/package.json`

### 3. Create Root Config Files

Create `vite.config.ts`, `tsconfig.json`, `eslint.config.mjs`, `.prettierrc.json`,
and `package.json` at the repo root. See [Reference: Configuration Files](#reference-configuration-files)
for the exact contents.

### 4. Update Backend References

Update these files with your project name:

**backend/go.mod** (line 1):
```diff
- module github.com/mauriceLC92/saas-template
+ module github.com/YOUR_ORG/YOUR_PROJECT
```

**package.json** scripts:
```diff
- "build:server": "... -o ../saas-template",
+ "build:server": "... -o ../YOUR_PROJECT",
- "preview": "./saas-template serve",
+ "preview": "./YOUR_PROJECT serve",
```

**Dockerfile** (3 places):
```diff
- RUN CGO_ENABLED=0 go build -tags production -o saas-template
+ RUN CGO_ENABLED=0 go build -tags production -o YOUR_PROJECT
- COPY --from=builder-go /app/saas-template .
+ COPY --from=builder-go /app/YOUR_PROJECT .
- CMD ["/app/saas-template", "serve", "--http=0.0.0.0:8090"]
+ CMD ["/app/YOUR_PROJECT", "serve", "--http=0.0.0.0:8090"]
```

**docker-compose.yml** (2 places):
```diff
  services:
-   saas-template:
+   YOUR_PROJECT:
      ...
-     container_name: saas-template
+     container_name: YOUR_PROJECT
```

### 5. Install and Verify

```bash
npm install
npm run dev
npm run build
npm run preview
```

---

## Using the Scaffolded Features

### Adding Protected Routes

To add a new protected route, follow the pattern in `router.tsx`:

```tsx
const myProtectedRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: 'my-page',
  component: MyPage,
  beforeLoad: () => {
    if (!checkVerifiedUserIsLoggedIn()) throw redirect({ to: '/' })
  }
})

// Add to routeTree
const routeTree = rootRoute.addChildren([homeRoute, dashboardRoute, myProtectedRoute])
```

### Building Login/Register UI

The hooks and services are ready - you just need to create the UI:

```tsx
// Example login form using use-auth hook
import useAuth from '@/hooks/use-auth'
import { loginSchema, LoginFields } from '@/schemas/auth-schema'

function LoginForm() {
  const { loginWithPassword } = useAuth()

  const onSubmit = async (data: LoginFields) => {
    try {
      await loginWithPassword(data.email, data.password)
      // Success - router navigates to /dashboard automatically
    } catch (error) {
      // Handle error (show toast, display message, etc.)
    }
  }

  // Build your form UI here...
}
```

### Adding Toast Notifications

The hooks don't include toast calls - add your preferred notification library:

```tsx
// With sonner
import { toast } from 'sonner'

// In your component
const { loginWithPassword } = useAuth()

const handleLogin = async (data) => {
  try {
    await loginWithPassword(data.email, data.password)
    toast.success('Logged in successfully')
  } catch (error) {
    toast.error('Could not log in', { description: error.message })
  }
}
```

### Using Catalyst UI Components

Catalyst UI Kit is included by default, so you have access to a comprehensive component library:

```tsx
// Import Catalyst components
import { Button } from '@/components/button'
import { Input } from '@/components/input'
import { Dialog, DialogTitle, DialogBody } from '@/components/dialog'

// Example usage with different variants
function MyComponent() {
  return (
    <div className='space-y-4'>
      <Button color='blue'>Primary Button</Button>
      <Button color='indigo' outline>
        Secondary Button
      </Button>
      <Input placeholder='Enter text...' />

      <Dialog open={isOpen} onClose={setIsOpen}>
        <DialogTitle>Confirm Action</DialogTitle>
        <DialogBody>Are you sure?</DialogBody>
      </Dialog>
    </div>
  )
}
```

Available components include:
- **Forms**: Input, Textarea, Select, Checkbox, RadioGroup, Switch
- **Buttons**: Button with multiple color and size variants
- **Modals**: Dialog, Drawer, Modal
- **Data Display**: Table, Badge, Avatar
- **Navigation**: Tab, Menu, Popover
- **Feedback**: Tooltip, Alert, Toast

For complete documentation and API reference, visit https://catalyst.tailwindui.com/docs

---

## Future Improvements

Potential enhancements for the scaffold script:

- [x] **Tailwind CSS**: Included via Catalyst UI Kit
- [x] **Catalyst UI Kit**: Premium accessible component library (Included by default)
- [x] ~~**TanStack integration**: Option to add Router + Query setup~~ (Now included!)
- [ ] **Auth pages scaffolding**: Generate login/register page UI components
- [x] ~~**API service template**: Generate typed PocketBase client wrapper~~ (Now included!)
- [ ] **Test setup**: Add Vitest configuration option
- [ ] **CI/CD templates**: GitHub Actions workflow for build/deploy
- [x] ~~**Fly.io config**: Auto-update fly.toml with project name~~ (Now included!)

---

## Troubleshooting

### "jq: command not found"

Install jq:
- macOS: `brew install jq`
- Ubuntu/Debian: `sudo apt install jq`
- Windows: `choco install jq`

### "frontend/ already exists"

The script will prompt you to delete it. If you want to keep it, back it up first:
```bash
mv frontend frontend.bak
./scripts/scaffold-frontend.sh
```

### ESLint errors after scaffolding

The Vite template may include code patterns our ESLint config warns about.
Run `npm run lint` to see issues, or `npm run pretty` to auto-fix formatting.

### Build fails with "Cannot find module '@/...'"

Ensure both `vite.config.ts` and `tsconfig.json` have matching `@` alias paths:
- vite.config.ts: `alias: { '@': path.resolve(__dirname, 'frontend/src') }`
- tsconfig.json: `"paths": { "@/*": ["./frontend/src/*"] }`

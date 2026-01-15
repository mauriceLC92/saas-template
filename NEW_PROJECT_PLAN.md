# New Project Plan: Stock Vite React Frontend + Embedded Go Backend

This document describes the simplest way to create a new project that mirrors
this repository's backend and embed workflow, but replaces the frontend with
the official Vite React template. The goal is to keep the same developer
experience (HMR, ESLint, Prettier, dev proxy, and production embed).

## Goals

- Keep the backend and embed flow unchanged.
- Use the official Vite React template as the frontend.
- Retain HMR, ESLint, and Prettier.
- Preserve the dev proxy (`/api`) and production embed (`backend/dist`).

## Copy List (from this repo to the new repo)

- `backend/` (exclude `backend/dist`)
- `Dockerfile`
- `docker-compose.yml`
- `fly.toml` (optional)
- `package.json`
- `vite.config.ts`
- `tsconfig.json`
- `eslint.config.mjs`
- `.prettierrc.json`

## Do Not Copy

- `frontend/` (old UI)
- `index.html` (root-level, old UI entry)
- `node_modules/`, `db/`, `backend/dist/`, `saas-template`

## Step-by-Step Setup

1) Create a new repository folder.
2) Copy the items from the "Copy List" above into the new repo.
3) Scaffold the official Vite React template inside `frontend/`:
   - `npm create vite@latest frontend -- --template react-ts`
4) Update Vite to use `frontend/` as the root and build into `backend/dist`.
5) Replace dependencies and lint/format configs with the minimal versions below.
6) Verify dev and production builds.

## Vite Config (root + embed output)

Update `vite.config.ts` so the Vite root is `frontend/` and the build output is
`backend/dist`. This keeps the backend embed flow unchanged.

```ts
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
```

## Minimal `package.json` Dependencies

Keep the existing scripts (they still work with `root: 'frontend'`) and replace
dependencies with the list below.

```json
{
  "scripts": {
    "dev:client": "vite dev",
    "dev:server": "cd backend && go run . --dir=../db serve",
    "dev": "npm run dev:client & npm run dev:server",
    "build:client": "npm run lint && vite build",
    "build:server": "cd backend && CGO_ENABLED=0 go build -tags production -o ../saas-template",
    "build": "npm run build:client && npm run build:server",
    "preview": "./saas-template serve",
    "compose": "docker compose up --build -d",
    "pretty": "prettier frontend/src --write",
    "lint": "tsc --noEmit && eslint frontend/src"
  },
  "dependencies": {
    "react": "^19.2.3",
    "react-dom": "^19.2.3"
  },
  "devDependencies": {
    "@types/react": "^19.1.9",
    "@types/react-dom": "^19.1.7",
    "@typescript-eslint/eslint-plugin": "^8.49.0",
    "@typescript-eslint/parser": "^8.49.0",
    "@vitejs/plugin-react": "^5.0.0",
    "eslint": "^9.39.2",
    "eslint-config-prettier": "^10.1.8",
    "eslint-plugin-react": "^7.37.5",
    "eslint-plugin-react-hooks": "^5.2.0",
    "eslint-plugin-react-refresh": "^0.4.20",
    "globals": "^16.3.0",
    "prettier": "^3.7.4",
    "typescript": "^5.9.2",
    "vite": "^7.1.1"
  }
}
```

## Minimal ESLint Config

Replace `eslint.config.mjs` with the following minimal flat config.

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

## Minimal Prettier Config

Remove Tailwind or other extra plugins if you are not using them.

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

## TypeScript Paths (optional)

If you keep the `@` alias in `vite.config.ts`, keep this in `tsconfig.json`:

```json
{
  "compilerOptions": {
    "paths": { "@/*": ["./frontend/src/*"] }
  }
}
```

## Verify

- `npm install`
- `npm run dev`
  - Vite HMR runs at `http://localhost:5173`
  - PocketBase reverse proxy runs at `http://localhost:8090`
- `npm run build`
  - Frontend output is in `backend/dist`
- `npm run preview`
  - Embedded frontend is served by the Go binary

## Backend Renaming Checklist

After copying `backend/`, update these files to use your new project name:

### 1. `backend/go.mod` (line 1)
```diff
- module github.com/mauriceLC92/saas-template
+ module github.com/YOUR_ORG/YOUR_PROJECT
```

### 2. `package.json` scripts
```diff
- "build:server": "cd backend && CGO_ENABLED=0 go build -tags production -o ../saas-template",
+ "build:server": "cd backend && CGO_ENABLED=0 go build -tags production -o ../YOUR_PROJECT",

- "preview": "./saas-template serve",
+ "preview": "./YOUR_PROJECT serve",
```

### 3. `Dockerfile` (lines 21, 30)
```diff
- RUN CGO_ENABLED=0 go build -tags production -o saas-template
+ RUN CGO_ENABLED=0 go build -tags production -o YOUR_PROJECT

- COPY --from=builder-go /app/saas-template .
+ COPY --from=builder-go /app/YOUR_PROJECT .

- CMD ["/app/saas-template", "serve", "--http=0.0.0.0:8090"]
+ CMD ["/app/YOUR_PROJECT", "serve", "--http=0.0.0.0:8090"]
```

### 4. `docker-compose.yml` (lines 2, 8)
```diff
  services:
-   saas-template:
+   YOUR_PROJECT:
      build:
        ...
-     container_name: saas-template
+     container_name: YOUR_PROJECT
```

---

## Complete tsconfig.json

Replace the partial config with this full version:

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

## Environment Variables

| Variable | Purpose | Default | Used By |
|----------|---------|---------|---------|
| `DB_DIR` | SQLite database directory | `db` | Backend |
| `VITE_BACKEND_URL` | Backend URL for dev proxy | `http://localhost:8090` | Vite |
| `VITE_DOMAIN` | Domain injected at build | - | Vite/Docker |
| `DOMAIN_NAME` | Docker build arg for domain | - | Dockerfile |
| `MAILER_CRON_SCHEDULE` | Email notification cron | `0 9 * * *` (9 AM daily) | Backend |
| `MAILER_NUM_WORKERS` | Email worker pool size | `10` | Backend |

---

## Database Setup

After the first run, set up PocketBase:

### 1. Create a Superuser
```bash
./YOUR_PROJECT superuser upsert admin@example.com yourpassword
```

### 2. Access Admin Dashboard
Open `http://localhost:8090/_/` in your browser.

### 3. Import Schema (Optional)
If starting from the full backend, import `backend/pb_schema.json` via the admin
dashboard to get the default collections (users, settings, tasks).

For a clean start, you can skip this and define your own collections.

---

## Email Template Branding

Update these files in `backend/templates/` with your project branding:

| File | Purpose | What to Update |
|------|---------|----------------|
| `base.layout.gohtml` | HTML wrapper | Company name, meta tags |
| `styles.partial.gohtml` | Inline CSS | Brand colors, fonts |
| `verify-email.page.gohtml` | Email verification | Subject line, copy |
| `reset-password.page.gohtml` | Password reset | Subject line, copy |
| `auth-alert.page.gohtml` | Login alert | Subject line, copy |
| `tasks.page.gohtml` | Task reminders | Rename/remove if not using tasks |

Also update the sender email in `backend/notifier/email.go`:
```diff
- From: "noreply@saas-template.com"
+ From: "noreply@YOUR_DOMAIN.com"
```

---

## Recommended .gitignore

Add these entries to your `.gitignore`:

```gitignore
# Dependencies
node_modules/

# Build outputs
backend/dist/
YOUR_PROJECT
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

---

## Migration Checklist

- Remove root `index.html` and any old `frontend/` files from the source repo.
- Confirm `frontend/index.html` exists (Vite template default).
- Verify `vite.config.ts` uses `root: 'frontend'` and `build.outDir: '../backend/dist'`.
- Ensure `frontend/public/` holds any icons or `manifest` you want to keep.
- Keep `/api` proxy + `VITE_BACKEND_URL` in `vite.config.ts`.
- Align `@` alias in `vite.config.ts` and `tsconfig.json` if you use it.
- Trim `package.json` dependencies to the minimal list.
- Update `eslint.config.mjs` and `.prettierrc.json` to match the minimal configs.
- **Complete the Backend Renaming Checklist above.**
- **Update email templates with your branding.**
- **Add the recommended .gitignore entries.**

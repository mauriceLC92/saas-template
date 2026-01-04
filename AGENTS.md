# Repository Guidelines

## Project Structure & Module Organization

- `frontend/`: Vite + React + TypeScript client
  - `frontend/src/pages/`: route-level pages (auth, tasks, etc.)
  - `frontend/src/components/`: shared + feature UI (shadcn/ui in `components/ui/`)
  - `frontend/src/services/`: PocketBase client and API helpers
  - `frontend/public/`: static assets (icons, images)
- `backend/`: Go + PocketBase server
  - `backend/main.go`: app entrypoint; serves API and embeds `backend/dist/` in production builds
  - `backend/templates/`: email templates (`*.gohtml`)
  - `backend/pb_schema.json`: PocketBase collections schema for import/export
- Root tooling: `vite.config.ts` builds the client into `backend/dist/`; `Dockerfile`, `docker-compose.yml`, and `fly.toml` support deployments.

## Build, Test, and Development Commands

Prereqs: Go 1.25+, Node.js 24+.

- `npm install`: install frontend/tooling dependencies.
- `npm run dev`: run Vite (`http://localhost:5173`) and PocketBase (`http://localhost:8090`) together.
- `npm run dev:client`: run only the Vite dev server.
- `npm run dev:server`: run only the PocketBase server (stores data under `db/`).
- `npm run lint`: TypeScript typecheck (`tsc --noEmit`) + ESLint on `frontend/src`.
- `npm run pretty`: format `frontend/src` with Prettier.
- `npm run build`: build frontend and compile the Go binary (`./saas-template`).
- `npm run preview`: serve the production build via the compiled binary.
- `npm run compose`: build and start Docker services via Compose.

## Coding Style & Naming Conventions

- TypeScript/React: 2-space indentation, single quotes, and no semicolons (see `.prettierrc.json`).
- ESLint is scoped to `frontend/src/**/*.{ts,tsx}`; intentionally-unused variables should be prefixed with `_`.
- Imports should prefer the alias `@/…` for `frontend/src/*`.
- Go: run `gofmt` on all backend changes; keep package boundaries clear (`backend/notifier/`, `backend/templates/`).

## Testing Guidelines

- Frontend: no test runner is configured yet; rely on `npm run lint` and manual smoke testing for changed flows.
- Backend: add standard Go tests as `*_test.go` and run `go test ./...` from `backend/`.

## Commit & Pull Request Guidelines

- Commit messages in history are short and imperative (for example: “bump package versions”); keep subjects focused and ≤72 chars.
- PRs should include: a brief description of the change, verification steps, and screenshots for UI changes.
- Before opening a PR, run `npm run lint` (and `npm run build` when touching build/deploy paths).

## Security & Configuration Tips

- Do not commit secrets; `.env` is ignored. For local routing/proxying, set `VITE_BACKEND_URL` (for example in `.env.local`).
- Build artifacts are ignored (`backend/dist/`, `saas-template`, `db/`); avoid committing generated output.

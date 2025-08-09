# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Frontend & Full Stack Development
- `npm run dev` - Start development servers (frontend on port 5173, backend on port 8090)
- `npm run dev:client` - Start only Vite frontend development server
- `npm run dev:server` - Start only Go/PocketBase backend server
- `npm run build` - Build both frontend and backend for production
- `npm run build:client` - Build only frontend (runs lint first)
- `npm run build:server` - Build only backend Go binary
- `npm run preview` - Run the production build locally

### Code Quality
- `npm run lint` - Run TypeScript compiler check and ESLint on frontend code
- `npm run pretty` - Format frontend code with Prettier
- `tsc --noEmit` - TypeScript type checking without emitting files

### Backend Commands
- `cd backend && go run . serve` - Start PocketBase server directly
- `./longhabit serve` - Run compiled production binary
- `./longhabit superuser upsert <email> <password>` - Create admin user for PocketBase dashboard

### Docker & Deployment
- `npm run compose` - Build and run with Docker Compose
- Access PocketBase admin dashboard at `http://localhost:8090/_/`

## Architecture Overview

This is a full-stack SaaS template built as a habit tracking application with PocketBase backend and React frontend.

### Backend Architecture (`/backend/`)
- **PocketBase Framework**: Go-based backend using PocketBase v0.29 as a framework (not just database)
- **Single Binary**: Frontend is embedded in Go binary using `embed` package for production builds
- **Custom Extensions**: Extensive use of PocketBase hooks, middleware, and custom routes
- **Email System**: Worker pool implementation using Pond library for bulk email processing
- **Database**: SQLite with PocketBase's ORM layer
- **Key Files**:
  - `main.go` - Application entry point and configuration
  - `auth.go` - Authentication hooks and middleware
  - `mailer.go` - Email functionality with worker pools
  - `notifier/` - Scheduled notification system with cron jobs
  - `templates/` - HTML email templates using Go templates

### Frontend Architecture (`/frontend/src/`)
- **React 19**: Modern React with React Compiler enabled
- **TanStack Router**: File-based routing with type-safe navigation and authentication guards
- **TanStack Query**: Server state management with PocketBase integration
- **TanStack Table**: Data grid implementation for task management
- **Authentication Flow**: Complete auth system with email verification and OAuth
- **UI Framework**: shadcn/ui components built on Radix UI and TailwindCSS
- **Forms**: React Hook Form + Zod validation with reusable form components
- **Theming**: Dark/light mode support with next-themes

### Key Frontend Patterns
- **Route Protection**: Authentication guards in router configuration (`router.tsx:109-125`)
- **Data Loading**: TanStack Query integrated with router loaders for pre-fetched data
- **API Layer**: Centralized API services in `/services/` with consistent error handling
- **Schema Validation**: Shared Zod schemas in `/schemas/` for forms and API responses
- **Component Structure**: 
  - `/components/ui/` - Base UI components from shadcn/ui
  - `/components/form/` - Reusable form field components
  - `/components/tasks/` - Feature-specific components
  - `/components/shared/` - Common components (spinner, logos)

### State Management
- **Server State**: TanStack Query handles all server communication and caching
- **Client State**: React context for theme and Plausible analytics
- **Form State**: React Hook Form for complex forms with validation
- **Route State**: TanStack Router manages route-level state and search params

### Build System
- **Vite**: Fast development and optimized production builds
- **TypeScript**: Strict type checking with path aliases (`@/` -> `frontend/src/`)
- **Bundle Splitting**: Manual chunks for data, forms, and UI libraries (see `vite.config.ts:20-58`)
- **Embedded Assets**: Frontend builds to `backend/dist/` for embedding in Go binary

### Development Workflow
1. Run `npm run dev` to start both frontend (port 5173) and backend (port 8090)
2. Frontend proxies API requests to backend during development
3. Access PocketBase admin at `http://localhost:8090/_/` for database management
4. Import database schema from `backend/pb_schema.json` on first setup
5. Use `npm run lint` before committing to ensure code quality

### Database Schema
- Database schema is defined in `backend/pb_schema.json`
- Import this file into PocketBase admin dashboard after creating superuser
- Main collections: users, tasks, and their relationships
- Authentication handled by PocketBase's built-in user system

### Testing & Production
- No specific test commands defined in package.json - check if tests exist
- Production builds create a single binary that serves both frontend and API
- Docker support with multi-stage builds for containerized deployment
- Health check endpoint available for deployment monitoring
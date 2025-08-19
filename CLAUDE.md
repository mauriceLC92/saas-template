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
- `./saas-template serve` - Run compiled production binary (binary name matches go.mod module)
- `./saas-template superuser upsert <email> <password>` - Create admin user for PocketBase dashboard

### Docker & Deployment
- `npm run compose` - Build and run with Docker Compose
- Access PocketBase admin dashboard at `http://localhost:8090/_/`

## Architecture Overview

This is a full-stack SaaS template with PocketBase backend and React frontend. Originally based on a habit tracking application but designed as a reusable template for building any CRUD-based SaaS application.

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
- **Client State**: React context for theme management
- **Form State**: React Hook Form for complex forms with validation
- **Route State**: TanStack Router manages route-level state and search params

### Build System
- **Vite**: Fast development and optimized production builds with React Compiler support
- **TypeScript**: Strict type checking with path aliases (`@/` -> `frontend/src/`)
- **Bundle Splitting**: Manual chunks for data, forms, and UI libraries (see `vite.config.ts:20-58`)
- **Embedded Assets**: Frontend builds to `backend/dist/` for embedding in Go binary
- **Go Module**: Uses `github.com/mauriceLC92/saas-template` as module name (updated from original)

### Development Workflow
1. Run `npm run dev` to start both frontend (port 5173) and backend (port 8090)
2. Frontend proxies API requests to backend during development  
3. Access PocketBase admin at `http://localhost:8090/_/` for database management
4. Import database schema from `backend/pb_schema.json` on first setup
5. Use `npm run lint` before committing to ensure code quality
6. Database files are stored in `/db` directory in project root
7. Backend uses `--dir=../db` flag to specify database location during development

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

## SaaS Development Patterns

This section documents the established architectural patterns used throughout the codebase. **Always follow these patterns when creating new features to maintain consistency.**

### Page Architecture Patterns

#### Standard Page Structure
Pages should follow this consistent structure:

```tsx
// Standard imports pattern
import ComponentName from '@/components/...'
import { Button } from '@/components/ui/button'
import useHookName from '@/hooks/use-hook-name'

export default function PageName() {
  const { data, action } = useHookName()
  
  return (
    <main className='flex flex-col gap-8 text-justify text-lg'>
      {/* Page content */}
    </main>
  )
}
```

**Key Pattern Rules:**
- Always use `main` wrapper with consistent responsive classes
- Import UI components from `@/components/ui/`
- Import custom hooks from `@/hooks/`
- Use `@/` path alias for all internal imports
- Keep pages thin - delegate logic to hooks

#### Authentication-Aware Pages
Pages requiring authentication should:
1. Be protected in router configuration (`router.tsx:172-175`)
2. Use `useAuth()` hook to access user data
3. Handle authentication state through router guards, not component-level checks

#### Modal/Sheet Integration Pattern
For CRUD operations using nested routes:
- Parent page: Renders table/list + `<Outlet />` in a Sheet component (`tasks.tsx:15-19`)
- Child pages: Return `<SheetContent>` with form component (`new-task.tsx:4-10`)
- Navigation: Use `navigate({ to: '/parent-route' })` to close modals

### Hook Patterns (`/hooks/use-*.ts`)

#### Standard Hook Structure
Custom hooks should follow this pattern (`use-tasks.ts`):

```tsx
export default function useFeatureName() {
  const queryClient = useQueryClient()
  const navigate = useNavigate()

  // 1. Data queries using useSuspenseQuery
  const { data: items } = useSuspenseQuery(itemsQueryOptions)

  // 2. Mutations with consistent error handling
  const createMutation = useMutation({
    mutationFn: ({ id, data }) => createItemApi(id, data),
    
    onSuccess: (_, context) => {
      successToast('Success message', `Detail: ${context.data.name}`)
      navigate({ to: '/target-route' })
    },
    
    onError: (error) => {
      console.error(error)
      errorToast('Error message', error)
    },
    
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['items'] })
    }
  })

  // 3. Optimistic updates for better UX (see use-tasks.ts:73-90)
  const updateMutation = useMutation({
    onMutate: async ({ id, data }) => {
      await queryClient.cancelQueries({ queryKey: ['items'] })
      const previousItems = queryClient.getQueryData(['items'])
      
      queryClient.setQueryData(['items'], (current) => 
        current.map(item => item.id === id ? { ...item, ...data } : item)
      )
      
      return { previousItems }
    },
    // ... rest of mutation
  })

  // 4. Return object with data and actions
  return {
    items,
    createItem: (data) => createMutation.mutate(data),
    updateItem: (id, data) => updateMutation.mutate({ id, data })
  }
}
```

**Hook Pattern Rules:**
- Always use `useSuspenseQuery` for data fetching (enables Suspense boundaries)
- Use consistent toast notifications (`successToast`, `errorToast`)
- Navigate after successful mutations
- Implement optimistic updates for better UX on updates
- Always invalidate relevant queries in `onSettled`
- Export functions, not mutation objects

### Service Layer Patterns (`/services/api-*.ts`)

#### API Service Structure
Services should follow this pattern (`api-tasks.ts`):

```tsx
// 1. Standard imports
import { PbId } from '@/schemas/pb-schema'
import { Item, itemSchema, itemListSchema } from '@/schemas/item-schema'
import { queryOptions } from '@tanstack/react-query'
import { pb } from './pocketbase'

// 2. CRUD functions with Zod validation
export async function getAllItems() {
  const items = await pb.collection('items').getFullList()
  return itemListSchema.parse(items)
}

export async function getItemById(itemId: PbId) {
  const item = await pb.collection('items').getOne(itemId)
  return itemSchema.parse(item)
}

export async function createItem(userId: PbId, data: Item) {
  return pb.collection('items').create({ ...data, user: userId })
}

// 3. Query options exports
export const itemsQueryOptions = queryOptions({
  queryKey: ['items'],
  queryFn: () => getAllItems(),
  staleTime: 30 * 1000,
  gcTime: 5 * 60 * 1000,
  refetchInterval: 5 * 60 * 1000
})
```

**Service Pattern Rules:**
- Always validate API responses with Zod schemas
- Export `queryOptions` for each data type
- Use consistent cache timing (30s stale, 5min garbage collection)
- Include refetch intervals for live data
- Use PbId type for ID parameters
- All functions should be async and handle PocketBase errors

### Form Patterns

#### Standard Form Setup
Forms should use React Hook Form + Zod with this pattern (`task-form.tsx`):

```tsx
import { zodResolver } from '@hookform/resolvers/zod'
import { useForm } from 'react-hook-form'

const form = useForm<FormType>({
  resolver: zodResolver(formSchema) as Resolver<FormType>,
  defaultValues: {
    field1: existingData?.field1 || '',
    field2: existingData?.field2 || false
  }
})

const fieldsEdited = form.formState.isDirty

function onSubmit(values: FormType) {
  if (!fieldsEdited) {
    navigate({ to: '/back-route' })
    return
  }
  // Handle create vs update logic
}
```

#### Reusable Form Components
Always use the established form field components:
- `<InputField form={form} name="fieldName" />`
- `<PasswordField form={form} name="password" />`
- `<TextAreaField form={form} name="description" />`
- `<SwitchField form={form} name="enabled" label="Enable feature" />`
- `<AutoCompleteField form={form} name="category" options={options} />`

### Schema Patterns (`/schemas/*-schema.ts`)

#### Zod Schema Structure
Follow this pattern for data schemas:

```tsx
import { z } from 'zod/v4'
import { pbIdSchema } from './pb-schema'

export const itemSchema = z.object({
  id: pbIdSchema.optional(),
  name: z.string().min(2, 'Too short'),
  description: z.string().optional(),
  enabled: z.boolean().default(false)
})

export const itemListSchema = z.array(itemSchema)
export type Item = z.output<typeof itemSchema>
```

### Component Architecture

#### UI Component Usage
- **Base Components**: Use shadcn/ui components from `/components/ui/`
- **Form Components**: Use established form fields from `/components/form/`
- **Feature Components**: Create in feature-specific directories (e.g., `/components/tasks/`)
- **Shared Components**: Common components go in `/components/shared/`

#### Import Patterns
Always follow these import conventions:
```tsx
// 1. React/library imports first
import { useState } from 'react'
import { useForm } from 'react-hook-form'

// 2. Component imports (UI first, then custom)
import { Button } from '@/components/ui/button'
import CustomComponent from '@/components/feature/custom-component'

// 3. Hook and service imports
import useFeature from '@/hooks/use-feature'

// 4. Utility and schema imports
import { cn } from '@/lib/shadcn'
import { itemSchema } from '@/schemas/item-schema'
```

### Data Flow Architecture

#### Standard Data Flow: Router → Hook → Service
1. **Router Level**: Authentication guards and data pre-loading
2. **Hook Level**: TanStack Query integration, mutations, navigation logic
3. **Service Level**: Direct PocketBase API calls with validation
4. **Component Level**: UI rendering and user interactions

#### Authentication Integration
- **Route Guards**: Defined in `router.tsx` using `beforeLoad`
- **User Data**: Access via `useAuth()` hook
- **Auth State**: Managed by TanStack Query with PocketBase integration
- **Navigation**: Auto-redirect on auth state changes

#### Real-time Updates
For live data updates, follow the PocketBase subscription pattern (`api-auth.ts:77-96`):
```tsx
export async function subscribeToChanges(id: string, callback: (record: Item) => void) {
  try {
    pb.collection('items').subscribe(id, (event) => {
      const data = itemSchema.parse(event.record)
      callback(data)
    })
  } catch (error) {
    console.error('Subscription error:', error)
  }
}
```

### TypeScript Patterns

#### Type Safety Rules
- Use Zod schemas to generate TypeScript types: `type Item = z.output<typeof itemSchema>`
- Always type hook parameters and return values
- Use `Resolver<T>` type for React Hook Form resolvers
- Import types from schema files, not API responses
- Use `PbId` type for all database IDs

This pattern documentation ensures all new features integrate seamlessly with the existing architecture while maintaining type safety, user experience consistency, and code organization standards.
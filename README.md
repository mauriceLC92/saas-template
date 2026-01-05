![License](https://img.shields.io/badge/license-MIT-green)

# SaaS Template

A production-ready, white-label SaaS template built with PocketBase and React. This template is based on the excellent [longhabit](https://github.com/s-petr/longhabit) project and has been refactored into a reusable template that you can easily customize for your own SaaS applications.

## Why Use This Template?

This template provides a solid foundation for building modern SaaS applications with:

- **Full-stack architecture** - Complete backend and frontend integration
- **Production-ready** - Includes authentication, database, email templates, and deployment configs
- **Modern tech stack** - React 19, TypeScript, PocketBase, TailwindCSS
- **Best practices** - Established patterns for components, forms, API services, and state management
- **Developer experience** - Hot reload, linting, type safety, and comprehensive documentation

Perfect for entrepreneurs, indie hackers, or development teams who want to skip the boilerplate and focus on building their unique features.

## Key Features

### Backend Architecture
- **PocketBase v0.34** - Modern Go-based backend framework with built-in admin dashboard
- **Single binary deployment** - Frontend embedded in Go binary for easy deployment
- **Custom extensions** - Hooks, middleware, custom routes, and scheduled tasks
- **Email system** - Worker pool implementation for bulk email processing
- **Database** - SQLite with PocketBase's ORM layer and real-time subscriptions

### Frontend Implementation
- **React 19** - Latest React with React Compiler enabled for optimal performance
- **TypeScript** - Full type safety with strict configuration
- **TanStack Router** - File-based routing with authentication guards and data pre-loading
- **TanStack Query** - Server state management with optimistic updates
- **shadcn/ui + TailwindCSS** - Modern, accessible UI components with dark/light mode
- **React Hook Form + Zod** - Type-safe forms with validation
- **Responsive design** - Mobile-first approach with comprehensive breakpoints

### Developer Experience
- **Hot reload** - Vite dev server with PocketBase proxy integration
- **Code quality** - ESLint 9, Prettier, TypeScript strict mode
- **Build optimization** - Manual chunk splitting and bundle optimization
- **Docker support** - Multi-stage builds with slim Alpine containers
- **Single command deployment** - Build both frontend and backend together

## Tech Stack

- **Frontend**
  - [React 19](https://react.dev/blog/2024/04/25/react-19) - UI framework with React Compiler
  - [TypeScript](https://www.typescriptlang.org/) - Type safety
  - [Vite](https://vite.dev/guide/) - Build tool and dev server
  - [TanStack Router](https://tanstack.com/router/latest) - Type-safe routing
  - [TanStack Query](https://tanstack.com/query/latest) - Server state management
  - [TanStack Table](https://tanstack.com/table/latest) - Data grids
  - [shadcn/ui](https://ui.shadcn.com/) - UI component library
  - [TailwindCSS](https://tailwindcss.com/) - Utility-first CSS
  - [React Hook Form](https://react-hook-form.com/) - Form management
  - [Zod](https://zod.dev/) - Schema validation

- **Backend**
  - [Go 1.25+](https://go.dev/) - Backend language
  - [PocketBase](https://pocketbase.io/) - Backend framework and database
  - [Pond](https://github.com/alitto/pond) - Worker pool implementation

- **Deployment**
  - [Docker](https://docs.docker.com/) - Containerization
  - Single binary deployment option
  - Multi-stage Dockerfile with Alpine Linux

## Getting Started

### Prerequisites
- Go 1.25+
- Node.js 24+ or Bun or Bun (or Bun)
- Docker (optional)

### Quick Start

1. **Clone the template**
   ```bash
   git clone https://github.com/mauriceLC92/saas-template
   cd saas-template
   ```

2. **Install dependencies**
   ```bash
   npm install
   # or
   bun install
   ```

3. **Build and setup admin user**
   ```bash
   npm run build
   ./saas-template superuser upsert admin@example.com yourpassword
   ```

4. **Import database schema**
   - Start the server: `npm run dev`
   - Go to PocketBase admin: http://localhost:8090/_/
   - Login with your admin credentials
   - Navigate to Settings → Import collections → Load from JSON file
   - Select `backend/pb_schema.json` and import

5. **Start developing**
   ```bash
   npm run dev
   ```
   - Frontend: http://localhost:5173
   - Backend API: http://localhost:8090
   - PocketBase Admin: http://localhost:8090/_/

### Development Commands

```bash
# Development
npm run dev              # Start both frontend and backend
npm run dev:client       # Start only frontend (Vite)
npm run dev:server       # Start only backend (PocketBase)

# Building
npm run build            # Build both frontend and backend
npm run build:client     # Build only frontend
npm run build:server     # Build only backend
npm run preview          # Run production build locally

# Code Quality
npm run lint             # TypeScript check + ESLint
npm run pretty           # Format code with Prettier

# Deployment
npm run compose          # Build and run with Docker Compose
```

## Customizing for Your SaaS

### 1. Update Project Metadata

Edit `package.json`:
```json
{
  "name": "your-saas-name",
  "description": "Your SaaS description",
  "author": {
    "name": "Your Name",
    "github": "your-github"
  },
  "repository": {
    "type": "git",
    "url": "https://github.com/your-username/your-repo"
  },
  "homepage": "https://your-saas.com"
}
```

### 2. Update Go Module

Edit `backend/go.mod`:
```go
module github.com/your-username/your-saas

go 1.24.0
// ... rest of dependencies
```

Update import in `backend/mailer.go`:
```go
import "github.com/your-username/your-saas/notifier"
```

### 3. Customize Database Schema

- Modify `backend/pb_schema.json` to match your data model
- Or start fresh and create collections via the PocketBase admin UI
- Export your schema: Settings → Export collections → Download as JSON

### 4. Update Branding and Content

- Replace `frontend/public/` assets (logos, favicons, og-image.png)
- Update `index.html` meta tags and title
- Modify email templates in `backend/templates/`
- Update component text and labels throughout `frontend/src/`

### 5. Configure Authentication

For Google OAuth (optional):
- Get Google OAuth 2.0 credentials from [Google Cloud Console](https://console.cloud.google.com/)
- In PocketBase admin: Collections → Users → Edit → OAuth2 → Add Google provider
- Add your Client ID and Client Secret

### 6. Environment Variables

Create `.env.local` for development:
```env
VITE_BACKEND_URL=http://localhost:8090
```

### 7. Deployment Configuration

Update `docker-compose.yml`, `Dockerfile`, or deployment configs as needed for your hosting platform.

## Architecture Overview

This template follows established patterns documented in `CLAUDE.md`:

- **Pages**: Thin components that delegate logic to hooks
- **Hooks**: Custom hooks for data fetching and mutations using TanStack Query
- **Services**: API layer with Zod validation and query options
- **Components**: Reusable UI components with consistent patterns
- **Forms**: React Hook Form + Zod with reusable field components
- **Schemas**: Zod schemas for type safety and validation

## Production Deployment

### Single Binary
```bash
npm run build
./saas-template serve
```

### Docker
```bash
# Development
npm run compose

# Production
docker build -t your-saas .
docker run -p 8090:8090 your-saas
```

### Environment Setup
- Database files are stored in `/db` directory
- Ensure proper file permissions for PocketBase to write to database directory
- Configure your domain in PocketBase admin for email links and OAuth

## Contributing

This template is designed to be forked and customized. If you make improvements that would benefit the template itself (not your specific SaaS), feel free to contribute back:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - see [LICENSE.md](LICENSE.md) for details.

## Credits

Based on the excellent [longhabit](https://github.com/s-petr/longhabit) project by [Sergei Petrov](https://github.com/s-petr). This template extracts and generalizes the solid architectural patterns from that project into a reusable SaaS foundation.

## Support

- 📖 [Full Documentation](CLAUDE.md) - Comprehensive development guide
- 🐛 [Issues](https://github.com/mauriceLC92/saas-template/issues) - Bug reports and feature requests
- 💡 [Discussions](https://github.com/mauriceLC92/saas-template/discussions) - Questions and community support

---

**Ready to build your SaaS?** Clone this template and start customizing! 🚀
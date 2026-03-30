# OneSQLx

Open-source, SQL-first analytics platform built with Elixir and Phoenix. Connect external PostgreSQL databases to explore schemas, run read-only queries, save and organize analytical knowledge, build dashboards, automate scheduled reports, and monitor usage.

- **SQL-first**: SQL is a core capability, not an afterthought.
- **PostgreSQL-first**: deep integration with pg_catalog, introspection, and autocomplete.
- **Open source**: useful, transparent, and extensible.
- **Workspace-based**: analytical knowledge belongs to teams and workspaces.
- **Automation-ready**: uses Oban for reliable background tasks, scheduled queries, and maintenance.

## Features

### Data Sources
- Connect multiple external PostgreSQL databases with encrypted credentials
- Test connection before saving
- SSL support and read-only enforcement

### Catalog Explorer
- Automatic schema, table, and column introspection via pg_catalog
- Background sync with Oban (`catalog_sync` queue)
- SQL autocomplete powered by catalog metadata

### SQL Editor
- CodeMirror 6 editor with SQL syntax highlighting
- Autocomplete from catalog metadata (schemas, tables, columns)
- Query execution with row limits, timeouts, and SQL guard (blocks writes)
- Query history sidebar with re-execution
- Named parameter support (`:param_name` syntax with input form)
- CSV export of results

### Saved Queries
- Save queries with title, description, tags, and favorites
- Organize into collections/folders
- Search by title, filter by data source, tag, or collection
- Open in SQL Editor for re-execution

### Dashboards
- Create dashboards with card-based layout
- Card types: table, KPI, bar chart, line chart (Chart.js)
- Async per-card query execution with loading states
- Edit mode: add, remove, reorder cards
- CSV export from table cards
- Parameter defaults per card via config

### Scheduled Queries
- Schedule saved queries to run hourly, daily, weekly, or custom cron
- Minimal 5-field cron parser (supports `*`, ranges, steps, lists)
- Execution results stored with row count, duration, and error tracking
- Run history with status badges
- Manual "Run Now" from UI
- Automatic enqueue via Oban cron plugin (every minute)

### Usage Analytics
- KPI dashboard: total queries, success rate, avg duration, active users
- Slowest queries table
- Recent activity stream from audit events
- Date range filter (7d, 30d, 90d)

### Audit Trail
- Automatic event recording for query execution, saves, deletes, dashboard creation, data source creation
- Fire-and-forget audit via `Task.start/1` (never blocks parent operation)

### REST API
- Bearer token authentication (SHA-256 hashed, shown once at creation)
- Endpoints: saved queries (list, show, execute), dashboards (list, show with cards), data sources (list, no sensitive fields)
- Token management UI at `/settings/api-tokens`

### Workspace Management
- Multi-workspace with roles: owner, admin, member
- Workspace settings: rename, manage members, delete
- Cannot remove last owner (safety check)

### Maintenance
- Automated cleanup worker (daily at 3 AM via Oban cron):
  - Query runs > 90 days
  - Audit events > 180 days
  - Scheduled query runs > 30 days
  - Expired API tokens

## Tech Stack

| Technology | Purpose |
|---|---|
| Elixir 1.19 | Primary language |
| Erlang/OTP 28 | Runtime platform |
| Phoenix 1.8 | Web framework |
| Phoenix LiveView 1.1 | Real-time, server-rendered UI |
| Ecto | ORM and migrations (internal database) |
| Postgrex | Direct connection to external PostgreSQL |
| Oban | Background jobs (4 queues) |
| PostgreSQL 17 | Internal and external databases |
| Tailwind CSS v4 + DaisyUI | Styling and UI components |
| Chart.js | Bar and line chart rendering |
| CodeMirror 6 | SQL editor with autocomplete |
| Req | HTTP client |
| Mox | Mock external connections in tests |
| Credo | Static code analysis |

## Architecture

OneSQLx is a **modular monolith** with two clearly separated database worlds:

1. **Internal database** — managed with Ecto and migrations. Stores users, workspaces, saved queries, dashboards, schedules, audit events, API tokens, and connection settings.

2. **External PostgreSQL databases** — connected by users, accessed via Postgrex for catalog introspection and controlled read-only query execution.

### Domain Contexts

| Context | Module | Responsibility |
|---|---|---|
| Accounts | `Onesqlx.Accounts` | User auth, sessions, magic links, API tokens |
| Workspaces | `Onesqlx.Workspaces` | Workspaces, memberships, roles |
| DataSources | `Onesqlx.DataSources` | External PostgreSQL connections, encryption |
| Catalog | `Onesqlx.Catalog` | Schema/table/column introspection, sync |
| Querying | `Onesqlx.Querying` | SQL execution, SQL guard, parameter substitution |
| SavedQueries | `Onesqlx.SavedQueries` | Query persistence, search, collections |
| Dashboards | `Onesqlx.Dashboards` | Dashboards, cards, chart rendering |
| Scheduling | `Onesqlx.Scheduling` | Scheduled queries, cron parser, execution |
| Audit | `Onesqlx.Audit` | Event tracking, usage analytics |
| Export | `Onesqlx.Export` | CSV generation |
| Maintenance | `Onesqlx.Maintenance` | Automated data cleanup |

### Oban Queues

| Queue | Concurrency | Workers |
|---|---|---|
| `default` | 10 | General |
| `catalog_sync` | 5 | `Catalog.SyncWorker` |
| `scheduled_queries` | 10 | `ExecuteWorker`, `EnqueueDueWorker` |
| `maintenance` | 5 | `CleanupWorker` |

### Routes

**Authenticated (LiveView):**
- `/dashboards` — Dashboard listing and management
- `/dashboards/:id` — Dashboard view with async card execution
- `/sql-editor` — SQL Editor with CodeMirror
- `/saved-queries` — Saved query browser
- `/schedules` — Scheduled query management
- `/schedules/:id` — Schedule details and run history
- `/data-sources` — Data source connections
- `/data-sources/new` — Add new data source
- `/data-sources/:id/catalog` — Catalog explorer
- `/analytics` — Usage analytics dashboard
- `/workspace/settings` — Workspace settings and members
- `/settings/api-tokens` — API token management
- `/users/settings` — User account settings

**REST API (Bearer token auth):**
- `GET /api/saved-queries` — List saved queries
- `GET /api/saved-queries/:id` — Show saved query
- `POST /api/saved-queries/:id/execute` — Execute saved query
- `GET /api/dashboards` — List dashboards
- `GET /api/dashboards/:id` — Show dashboard with cards
- `GET /api/data-sources` — List data sources (no sensitive fields)

**Other:**
- `POST /exports/csv` — Download query results as CSV

## Local Development

### Prerequisites

- **[asdf](https://asdf-vm.com/) or [mise](https://mise.jdx.dev/)** — version manager (versions pinned in `.tool-versions`)
- **Docker & Docker Compose** — for PostgreSQL
- **Make** — build automation

```bash
asdf install   # or: mise install
```

### Quick Start

```bash
git clone https://github.com/aalvaropc/onesqlx.git
cd onesqlx
make setup
make start
```

The server will be available at [localhost:4000](http://localhost:4000).

### Commands

| Command | Description |
|---|---|
| `make setup` | Full setup (Docker + deps + DB + assets + git hooks) |
| `make start` | Start the Phoenix server |
| `make iex` | Start the server inside IEx |
| `make console` | Open an IEx console (no server) |
| `make test` | Run the test suite |
| `make test.failed` | Re-run previously failed tests |
| `make test.file F=path` | Run a single test file |
| `make test.integration` | Run integration tests (requires Docker) |
| `make cover` | Run tests with coverage report |
| `make lint` | Check formatting + Credo strict |
| `make precommit` | Full check (compile + format + credo + test) |
| `make format` | Auto-format all files |
| `make migrate` | Run pending migrations |
| `make rollback` | Rollback the last migration |
| `make routes` | List all application routes |
| `make db` | Start database containers |
| `make db.stop` | Stop database containers |
| `make db.reset` | Drop and recreate the dev database |
| `make clean` | Remove build artifacts |

### Testing

```bash
make test               # Unit tests (external connections mocked)
make test.integration   # Integration tests (requires Docker)
make cover              # With coverage
```

Tests use Ecto SQL Sandbox for isolation. Integration tests are tagged `@moduletag :integration` and excluded by default. External database connections use Mox (`MockConnection`).

### Development Tools

- **LiveDashboard**: `/dev/dashboard`
- **Mailbox preview**: `/dev/mailbox`

## Conventions

- **binary_id (UUID)** primary keys in all schemas
- **Scope-based auth**: `@current_scope` (never `@current_user`)
- **Workspace isolation**: all queries filter by `scope.workspace.id`
- **Streams** for collections in LiveView (never raw lists)
- **to_form/2** for all forms
- **Oban** for background jobs, scheduled execution, and maintenance
- **Req** as HTTP client (never HTTPoison, Tesla, or :httpc)
- **`mix precommit`** before every commit (compile warnings-as-errors, format, credo strict, test)

## License

This project is open source.

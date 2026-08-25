# OneSQLx

Open-source, SQL-first analytics platform built with Elixir and Phoenix. Connect external PostgreSQL databases to explore schemas, run read-only queries, save and organize analytical knowledge, build dashboards, automate scheduled reports, and monitor usage.

- **SQL-first**: SQL is a core capability, not an afterthought.
- **PostgreSQL-first**: deep integration with pg_catalog, introspection, and autocomplete.
- **Open source**: useful, transparent, and extensible.
- **Workspace-based**: analytical knowledge belongs to teams and workspaces.
- **Automation-ready**: uses Oban for reliable background tasks, scheduled queries, and maintenance.
- **API-first**: versioned REST API with scoped tokens, OpenAPI spec, and Swagger UI.

## Features

### Data Sources
- Connect multiple external PostgreSQL databases with encrypted credentials (AES-256-GCM)
- Test connection before saving
- SSL support and read-only enforcement (`default_transaction_read_only` per session)

### Catalog Explorer
- Automatic schema, table, and column introspection via pg_catalog
- Background sync with Oban (`catalog_sync` queue) and auto-refresh via PubSub when sync completes
- SQL autocomplete powered by catalog metadata

### SQL Editor
- CodeMirror 6 editor with SQL syntax highlighting
- Autocomplete from catalog metadata (schemas, tables, columns)
- Query execution with configurable row limits, timeouts, and SQL guard (blocks writes, including CTE-wrapped ones)
- Query cancellation (`pg_cancel_backend` via a second connection) and `EXPLAIN ANALYZE`
- Named parameter support (`:param_name`) with typed inputs auto-detected from parameter names
- Reusable SQL snippets with side panel
- SQL format button (keyword uppercasing, clause line breaks)
- Query history sidebar with re-execution
- Result tables: column sorting, click-to-copy cells, copy-row, expand truncated values
- Export results as CSV, JSON, or Excel (XLSX)

### Saved Queries
- Save queries with title, description, tags, and favorites
- Organize into collections/folders
- Search by title, filter by data source, tag, or collection
- Open in SQL Editor for re-execution

### Dashboards
- Card types: table, KPI, bar, line, pie, doughnut, area, scatter, and markdown text (Chart.js)
- Async per-card query execution with loading states and result caching
- Edit mode: add, remove, and drag-and-drop reorder cards (flexible grid with configurable card width)
- Cross-filtering between cards, KPI number formatting
- Duplicate a dashboard with all its cards
- Fullscreen presentation mode
- Public sharing: read-only link (`/share/:token`) and iframe embed (`/embed/:token`), revocable
- CSV export from table cards, parameter defaults per card via config

### Scheduled Queries
- Schedule saved queries to run hourly, daily, weekly, or custom cron (5-field parser with `*`, ranges, steps, lists)
- Conditional alerts on results (row count / value thresholds); errors and timeouts always alert
- Email notifications with HTML result table, plus webhook notifications
- Automatic retry for transient failures
- Run history with status badges and results viewer for previous runs
- Manual "Run Now" from UI; automatic enqueue via Oban cron plugin (every minute)

### Discovery & Governance
- Global search across saved queries, dashboards, schedules, and data sources (`/search`)
- Data lineage visualization: dashboards → queries → tables, and reverse table lineage (`/lineage`)
- Audit trail UI with filtering and CSV export (`/audit`); events recorded for query execution, saves, deletes, dashboard and data source creation — failures are logged, never crash the parent operation

### Usage Analytics
- KPI dashboard: total queries, success rate, avg duration, active users
- Slowest queries table
- Recent activity stream from audit events, with event type filter
- Date range filter (7d, 30d, 90d)

### REST API
- Versioned under `/api/v1`, Bearer token authentication (SHA-256 hashed, shown once at creation)
- Scoped tokens: `read`, `execute`, `manage` — each endpoint group enforces its scope
- Rate limiting per user (100 req/min for read/manage, 20 req/min for execute)
- Pagination via `limit`/`offset` (default 50, max 200)
- OpenAPI 3 spec at `/api/openapi` and Swagger UI at `/api/docs`
- Token management UI at `/settings/api-tokens`

### Authentication
- Magic link login (passwordless) as the primary method, password as secondary
- OAuth login with Google and GitHub (Ueberauth)
- Sudo mode: sensitive operations require recent authentication

### Workspace Management
- Multi-workspace with roles: owner, admin, member
- Role-based access control on resource mutations (members manage only what they created)
- Workspace settings: rename, manage members, delete
- Cannot remove last owner (safety check)

### Observability & Maintenance
- Health endpoints: `/health` (liveness) and `/ready` (readiness)
- Prometheus metrics endpoint at `/metrics`
- Automated cleanup worker (daily at 3 AM via Oban cron): query runs > 90 days, audit events > 180 days, scheduled query runs > 30 days, expired API tokens

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
| Chart.js | Chart rendering |
| CodeMirror 6 | SQL editor with autocomplete |
| Cachex | Dashboard query result caching |
| OpenApiSpex | OpenAPI 3 spec and Swagger UI |
| Ueberauth | OAuth (Google, GitHub) |
| Elixlsx | Excel (XLSX) export |
| Req | HTTP client |
| Mox + StreamData | Mocked connections and property-based tests |
| Credo | Static code analysis |

## Architecture

OneSQLx is a **modular monolith** with two clearly separated database worlds:

1. **Internal database** — managed with Ecto and migrations. Stores users, workspaces, saved queries, dashboards, schedules, audit events, API tokens, and connection settings.

2. **External PostgreSQL databases** — connected by users, accessed via Postgrex for catalog introspection and controlled read-only query execution.

### Domain Contexts

| Context | Module | Responsibility |
|---|---|---|
| Accounts | `Onesqlx.Accounts` | User auth, sessions, magic links, OAuth, API tokens |
| Workspaces | `Onesqlx.Workspaces` | Workspaces, memberships, roles |
| Authorization | `Onesqlx.Authorization` | Role-based rules for resource mutations |
| DataSources | `Onesqlx.DataSources` | External PostgreSQL connections, credential encryption |
| Catalog | `Onesqlx.Catalog` | Schema/table/column introspection, sync |
| Querying | `Onesqlx.Querying` | SQL execution, SQL guard, params, cancellation, caching |
| SavedQueries | `Onesqlx.SavedQueries` | Query persistence, search, collections |
| Snippets | `Onesqlx.Snippets` | Reusable SQL snippets |
| Dashboards | `Onesqlx.Dashboards` | Dashboards, cards, chart rendering, public tokens |
| Scheduling | `Onesqlx.Scheduling` | Scheduled queries, cron parser, alerts, notifications |
| Audit | `Onesqlx.Audit` | Event tracking, usage analytics |
| Lineage | `Onesqlx.Lineage` | Table references extracted from SQL, lineage graphs |
| Search | `Onesqlx.Search` | Global cross-resource search |
| Export | `Onesqlx.Export` | CSV generation (JSON/XLSX in web layer) |
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
- `/dashboards`, `/dashboards/:id` — Dashboard management and async card execution
- `/sql-editor` — SQL Editor with CodeMirror
- `/saved-queries` — Saved query browser
- `/schedules`, `/schedules/:id` — Scheduled query management and run history
- `/data-sources`, `/data-sources/new`, `/data-sources/:id/catalog` — Connections and catalog explorer
- `/analytics` — Usage analytics dashboard
- `/lineage` — Data lineage visualization
- `/audit` — Audit trail with filters and CSV export
- `/search` — Global search
- `/workspace/settings` — Workspace settings and members
- `/settings/api-tokens` — API token management
- `/users/settings` — User account settings

**Public (unauthenticated):**
- `/share/:token` — Read-only public dashboard
- `/embed/:token` — Embeddable dashboard (iframe-friendly)
- `/health`, `/ready` — Liveness and readiness probes
- `/metrics` — Prometheus metrics
- `/api/openapi`, `/api/docs` — OpenAPI spec and Swagger UI

**REST API (`/api/v1`, Bearer token auth with scopes):**
- `GET /api/v1/saved-queries`, `GET /api/v1/saved-queries/:id` — read scope
- `POST /api/v1/saved-queries/:id/execute` — execute scope (strict rate limit)
- `POST/PUT/DELETE /api/v1/saved-queries[...]` — manage scope
- `GET /api/v1/dashboards`, `GET /api/v1/dashboards/:id` — read; `POST`, `DELETE` — manage
- `GET /api/v1/schedules`, `GET /api/v1/schedules/:id` — read; `POST/PUT/DELETE` — manage
- `GET /api/v1/data-sources` — read (no sensitive fields)

**Exports (authenticated):**
- `POST /exports/csv` · `POST /exports/json` · `POST /exports/xlsx` — query results
- `POST /exports/audit-csv` — audit events

**OAuth:**
- `GET /auth/:provider`, `GET /auth/:provider/callback` — Google / GitHub

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

Tests use Ecto SQL Sandbox for isolation. Integration tests are tagged `@moduletag :integration` and excluded by default. External database connections use Mox (`MockConnection`). The SQL guard, parameter substitution, and cron parser also have property-based tests (StreamData).

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

## Contributing

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for the
development setup, project conventions, and how to open a pull request. Please
report security vulnerabilities privately, as described in
[SECURITY.md](SECURITY.md).

## License

Licensed under the [Apache License 2.0](LICENSE).

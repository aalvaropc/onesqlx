# OneSQLx

Open source, SQL-first analytics platform built with Elixir and Phoenix. Connect external PostgreSQL databases to explore schemas, run read-only queries, save queries, build dashboards, and automate background tasks.

- **SQL-first**: SQL is a core capability, not an afterthought.
- **PostgreSQL-first**: the MVP focuses on doing one integration really well.
- **Open source**: the product aims to be useful, transparent, and extensible.
- **Workspace-based**: analytical knowledge belongs to teams and workspaces.
- **Automation-ready**: uses Oban for reliable background tasks.

## MVP

The first version of OneSQLx will include:

- user authentication,
- workspaces with memberships and roles,
- external PostgreSQL database connections,
- catalog synchronization (schemas, tables, columns),
- visual catalog exploration,
- SQL editor with read-only query execution,
- saved queries organized by workspace,
- basic dashboards with panels and visualizations,
- scheduled query execution via Oban,
- audit logging and basic usage metrics.

## Tech Stack

| Technology | Purpose |
|---|---|
| Elixir | Primary language |
| Erlang/OTP | Runtime platform |
| Phoenix 1.8 | Web framework |
| Phoenix LiveView 1.1 | Real-time, server-rendered UI |
| Ecto | ORM and migrations (internal database) |
| Postgrex | Direct connection to external PostgreSQL |
| Oban | Background jobs |
| PostgreSQL 17 | Internal and external databases |
| Tailwind CSS v4 + DaisyUI | Styling and UI components |
| Req | HTTP client |
| Credo | Static code analysis |

## Architecture

OneSQLx starts as a **modular monolith**. This allows moving fast without losing internal order.

Two worlds are clearly separated:

1. **Internal product database** — managed with Ecto and migrations. Stores users, workspaces, saved queries, dashboards, connection settings, and audit logs.

2. **External PostgreSQL databases connected by users** — accessed via Postgrex for catalog introspection and controlled read-only query execution.

## Domain Contexts

The domain is organized into 9 contexts under `lib/onesqlx/`:

| Context | Module | Responsibility |
|---|---|---|
| Accounts | `Onesqlx.Accounts` | User authentication and management |
| Workspaces | `Onesqlx.Workspaces` | Workspaces, memberships, and roles |
| DataSources | `Onesqlx.DataSources` | External PostgreSQL connections |
| Catalog | `Onesqlx.Catalog` | Synchronized metadata (schemas, tables, columns) |
| Querying | `Onesqlx.Querying` | Read-only SQL execution against external sources |
| SavedQueries | `Onesqlx.SavedQueries` | Query persistence and organization |
| Dashboards | `Onesqlx.Dashboards` | Dashboards and panels with visualizations |
| Scheduling | `Onesqlx.Scheduling` | Scheduled query execution via Oban |
| Audit | `Onesqlx.Audit` | Activity tracking and system events |

## Local Development

### Prerequisites

- Elixir >= 1.15
- Erlang/OTP >= 26
- PostgreSQL 17 (via Docker or local)
- Node.js (for esbuild/tailwind, automatically installed by Mix)

### Setup

```bash
# 1. Start PostgreSQL with Docker
docker-compose up -d

# 2. Install dependencies, create DB, run migrations, and build assets
mix setup

# 3. Start the development server
mix phx.server
```

The server will be available at [localhost:4000](http://localhost:4000).

### Useful Commands

| Command | Description |
|---|---|
| `mix setup` | Full setup (deps, DB, migrations, assets) |
| `mix phx.server` | Start development server |
| `mix test` | Run all tests |
| `mix test test/path_test.exs` | Run a specific test file |
| `mix test --failed` | Re-run previously failed tests |
| `mix precommit` | Local CI: compile, deps, format, credo, test |
| `mix credo --strict` | Static analysis with Credo |
| `mix ecto.migrate` | Run pending migrations |
| `mix ecto.reset` | Drop and recreate the database |
| `mix ecto.gen.migration name` | Generate a new migration |
| `docker-compose up -d` | Start PostgreSQL 17 |

### Environment Variables

| Variable | Description | Default |
|---|---|---|
| `DATABASE_URL` | PostgreSQL connection URL | `postgres://postgres:postgres@localhost/onesqlx_dev` |
| `SECRET_KEY_BASE` | Phoenix secret key | Generated in `config/dev.exs` |
| `PHX_HOST` | Server hostname | `localhost` |
| `PORT` | HTTP port | `4000` |

### Development Tools

- **LiveDashboard**: `/dev/dashboard` — metrics and observability
- **Mailbox preview**: `/dev/mailbox` — email preview (Swoosh test adapter)

## Conventions

- **binary_id (UUID)** as primary key in all Ecto schemas.
- **Scope-based auth**: use `@current_scope` (never `@current_user`). Access the user via `@current_scope.user`.
- **Oban** for background jobs with queues: `default(10)`, `catalog_sync(5)`, `scheduled_queries(10)`, `maintenance(5)`.
- **Tailwind CSS v4** without `tailwind.config.js`. Custom components, don't use DaisyUI prebuilt ones.
- **Req** as HTTP client — never HTTPoison, Tesla, or :httpc.
- **`mix precommit`** required before every commit. Runs: compile with warnings-as-errors, deps check, format, credo strict, and tests.

## Future Vision

After the MVP, OneSQLx may evolve towards:

- parameterized queries,
- advanced dashboards with more visualization types,
- advanced schedules with notifications,
- result caching,
- usage observability,
- reusable models (SQL snippets),
- dashboards as code,
- support for multiple database engines,
- external integrations (Slack, email, webhooks).

## License

This project is open source.

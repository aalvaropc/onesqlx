# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Sample data** — `mix onesqlx.sample` (or `bin/onesqlx eval 'Onesqlx.Release.install_sample()'`
  in a release) installs a small e-commerce dataset in an `onesqlx_sample`
  schema, plus a data source, five saved queries, and a dashboard built on it,
  so a fresh instance has something to explore before connecting a database.
  The dataset is read through a dedicated PostgreSQL role granted `SELECT` only
  on that schema. `mix run priv/repo/seeds.exs` installs it automatically in
  development.

## [0.1.0] - 2026-08-17

First public release.

### Added

- **Data sources** — connect external PostgreSQL databases with AES-256-GCM
  encrypted credentials, connection testing, optional TLS, and per-source
  read-only enforcement at the session level.
- **Catalog explorer** — schema, table, and column introspection via
  `pg_catalog`, synced in the background with Oban and pushed to the UI over
  PubSub when it completes.
- **SQL editor** — CodeMirror 6 with catalog-driven autocomplete, multi-tab
  execution, named parameters with typed inputs, reusable snippets, query
  cancellation, `EXPLAIN ANALYZE`, query history, and CSV/JSON/XLSX export.
- **Saved queries** — titles, descriptions, tags, favorites, and collections.
- **Dashboards** — nine card types (table, KPI, bar, line, pie, doughnut, area,
  scatter, markdown), async per-card execution with result caching, drag-and-drop
  layout, cross-filtering, typed dashboard variables with defaults, revocable
  public share and iframe embed links, fullscreen mode, and live updates for
  concurrent viewers.
- **Scheduled queries** — hourly/daily/weekly/cron scheduling with a built-in
  5-field cron parser, conditional alerts on row counts and values, HTML email
  and webhook notifications, automatic retries, and run history.
- **Discovery and governance** — global search, data lineage graphs, and an
  audit trail with filtering and CSV export.
- **REST API** — versioned under `/api/v1` with scoped bearer tokens
  (`read`/`execute`/`manage`), rate limiting, pagination, an OpenAPI 3 spec, and
  Swagger UI.
- **Authentication** — passwordless magic links, password login, Google and
  GitHub OAuth, and sudo mode for sensitive operations.
- **Workspaces** — multi-workspace isolation with owner/admin/member roles.
- **Operations** — liveness and readiness probes, a token-protected Prometheus
  metrics endpoint, configurable data retention with an automated cleanup
  worker, a production Docker Compose stack that runs migrations on start, and a
  deployment runbook in `docs/deploy.md`.

[Unreleased]: https://github.com/aalvaropc/onesqlx/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/aalvaropc/onesqlx/releases/tag/v0.1.0

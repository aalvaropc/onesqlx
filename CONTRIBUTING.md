# Contributing to OneSQLx

Thanks for your interest in OneSQLx. This guide covers everything you need to
get a development environment running and to land a change.

## Getting started

**Prerequisites**: [asdf](https://asdf-vm.com/) or [mise](https://mise.jdx.dev/)
(versions are pinned in `.tool-versions`), Docker with Compose, and Make.

```bash
asdf install       # or: mise install
make setup         # Docker databases + deps + migrations + assets + git hooks
make start         # http://localhost:4000
```

`make setup` also points `core.hooksPath` at `.githooks/`, so the pre-commit
checks below run automatically.

## Development workflow

| Command | What it does |
|---|---|
| `make test` | Unit tests (external database connections are mocked with Mox) |
| `make test.integration` | Integration tests against the real Postgres containers |
| `make test.file F=path` | A single test file |
| `make lint` | Formatting check + Credo strict |
| `make precommit` | **The gate**: compile with warnings-as-errors, format, Credo strict, tests |
| `make routes` | List all application routes |

Run `mix precommit` before pushing — CI runs the same checks plus the
integration suite, and both must be green.

## Making a change

1. **Branch off `main`** using a prefix that matches the change: `feature/`,
   `fix/`, `chore/`, `refactor/`, `docs/`, or `test/`.
2. **Write tests.** Contexts get unit tests, LiveViews get
   `Phoenix.LiveViewTest` tests, and anything algorithmic (SQL guard, parameter
   substitution, cron parsing) is a good candidate for a property-based test
   with StreamData — see `test/onesqlx/querying/sql_guard_property_test.exs`.
3. **Commit with [Conventional Commits](https://www.conventionalcommits.org/)**:
   `feat(dashboards): add ...`, `fix(exports): ...`, `perf(querying): ...`.
   Explain *why* in the body, not just what.
4. **Open a pull request** using the template: what changed, why, and how to
   verify it.

## Project conventions

The full set lives in `AGENTS.md`; the ones that matter most:

- **Scope-based auth**: every context function takes `%Scope{}` as its first
  argument and filters by `scope.workspace.id`. Templates use
  `@current_scope.user` — never `@current_user`.
- **binary_id (UUID)** primary keys in every schema.
- **LiveView**: streams for collections, `to_form/2` for forms, function
  components over LiveComponents unless isolated state is genuinely needed.
- **Background work** goes through Oban; **HTTP** goes through `Req`.
- Markup for large LiveViews lives in a sibling `*_components.ex` module — see
  `lib/onesqlx_web/live/sql_editor_live/components.ex`.

## Architecture in one minute

OneSQLx is a modular monolith with two separate database worlds: the
**internal** database (Ecto + migrations: users, workspaces, saved queries,
dashboards, schedules, audit) and the **external** PostgreSQL databases that
users connect, reached through Postgrex for introspection and read-only query
execution.

External connections go through the `Onesqlx.DataSources.Connection` behaviour,
which is injected via config and mocked in tests. **If you want to add support
for another database engine, that behaviour is the seam to implement.**

Read-only enforcement has two layers: a lexical SQL guard
(`Onesqlx.Querying.SqlGuard`) and `SET default_transaction_read_only = on` at
the session level. Treat both as security-sensitive code.

## Reporting bugs and requesting features

Use the issue templates. For bugs, the most useful thing you can include is the
exact SQL or steps that reproduce it, plus your PostgreSQL version.

Security vulnerabilities: **do not open a public issue** — see
[SECURITY.md](SECURITY.md).

## License

By contributing, you agree that your contributions are licensed under the
Apache License 2.0, the same license that covers the project.

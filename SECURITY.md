# Security Policy

OneSQLx handles database credentials and executes SQL against production
databases, so security reports are taken seriously.

## Reporting a vulnerability

**Please do not open a public issue.** Report vulnerabilities privately through
[GitHub Security Advisories](https://github.com/aalvaropc/onesqlx/security/advisories/new),
which keeps the discussion confidential until a fix is available.

Useful things to include: the affected version or commit, how to reproduce, and
what an attacker gains.

## Supported versions

The project is pre-1.0: only the latest release receives security fixes.

## Security model

Things worth knowing when assessing a report:

- **Credentials** for external data sources are encrypted with AES-256-GCM. The
  key comes from `ENCRYPTION_KEY` when set, otherwise it is derived from
  `SECRET_KEY_BASE`. See `docs/deploy.md` for key rotation.
- **Read-only enforcement** has two layers: a lexical SQL guard
  (`Onesqlx.Querying.SqlGuard`) and `SET default_transaction_read_only = on` on
  every session. Data sources explicitly marked writable opt out of both — that
  is deliberate, and documented.
- **Query parameters** are always sent to PostgreSQL as bound placeholders,
  never string-interpolated.
- **Public dashboards** (`/share/:token`, `/embed/:token`) are unauthenticated
  by design. Tokens are revocable, and URL parameters are restricted to an
  allowlist of the dashboard's declared variables.
- **The Prometheus endpoint** (`/metrics`) requires a bearer token in production
  and returns 404 when `METRICS_TOKEN` is unset.

Reports that depend on an attacker already having valid credentials for a
workspace with the `manage` role, or on a data source deliberately configured as
writable, are usually working as intended — but send them anyway if something
looks off.

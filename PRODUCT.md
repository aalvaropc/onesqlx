# OneSQLx

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

The existing product serves people and teams who query PostgreSQL and share analytical work. SQL-literate analysts and developers are the design's inferred primary audience, based on the shipped editor, schema catalog, and README; the user delegated design decisions rather than specifying a new audience.

## Product Purpose

Connect PostgreSQL sources, explore schemas, execute SQL, save reusable queries, build dashboards, and automate scheduled reports in shared workspaces.

## Positioning

An open-source, SQL-first analytics workspace with PostgreSQL catalog introspection, a multi-tab SQL editor, dashboards, scheduled queries, and a scoped REST API. These are existing capabilities, not claims about competitors.

## Operating Context

Frequent desktop work with code, tables, charts, query history, and connection settings. Mobile access must preserve navigation, reading, and essential actions. Public dashboards and embeds are read-only sharing surfaces.

## Capabilities and Constraints

- Preserve Phoenix 1.8, LiveView, Tailwind v4, CodeMirror, Chart.js, and existing routes and authorization.
- Preserve owner, admin, member, and viewer permissions and workspace isolation.
- Cover the public home page, authentication, application navigation, SQL editor, saved queries, dashboards and sharing, schedules, sources and catalog, analytics, search, lineage, audit, workspace, API tokens, and account settings.
- Provide explicit light, dark, and system theme choices.
- Use the application's bundled assets; no runtime third-party scripts, remote stylesheets, or inline scripts in templates.
- Replace daisyUI's component styling with a project-owned component system.

## Brand Commitments

Keep the OneSQLx name and the factual open-source positioning. The user explicitly requested a complete redesign using Impeccable and delegated the appearance to the implementer. No existing palette or framework logo is a binding identity requirement.

## Evidence on Hand

README.md, the existing routes and LiveViews, and docs/screenshots contain the product's actual capabilities and sample e-commerce data. No customer endorsements, commercial pricing, usage metrics, or performance benchmarks were supplied; do not invent them.

## Product Principles

- Keep SQL and its results close together.
- Make the active workspace, location, and primary action easy to identify.
- Use one consistent interaction vocabulary across every screen.
- Represent permissions, loading, errors, and empty states clearly.
- Let analytical content carry the interface; decoration must earn its space.

# OneSQLx web redesign

## Scope

Replace the visual system across the existing Phoenix application, public home, authentication, and shared dashboards. Preserve routes, forms, hooks, DOM IDs used by tests, events, workspace scoping, and authorization. Operate mode governs the application; Persuade governs the home page. The user delegated all visual decisions and asked the implementer to proceed.

## Direction contract

THESIS: A precise analytical atlas: connections lead to SQL, SQL to results, and results to shared understanding. Each screen is a usable workspace with recognizable controls.

OWN-WORLD: Mineral green actions, ink and graphite navigation, cool white working surfaces, restrained dividers, 12px panels, Red Hat Text UI, Red Hat Display headlines, and Source Code Pro for code and measurement. Light supports daytime analysis; dark supports extended evening work.

STORY: Identify the workspace, find the right analytical object, act, and understand the result. The public page demonstrates the same journey using clearly labeled example data.

FIRST VIEWPORT: A 240px sidebar groups Explore, Observe, and Workspace. A 64px top bar names the current section and theme. Main content uses 32px margins and a single primary action. The SQL editor fills available width with tabs, a connection toolbar, code, results, and a history rail. The home pairs a large left-aligned headline with a substantial working-product demonstration on a forest field.

FORM: Grounded candidate 3, analytical atlas, seed 56c0315a. Alternatives considered: SQL workbench; research notebook; analytical atlas; financial ledger; operational control room; library catalog; observatory instrument. The external roll catalog was unavailable after permission-review timeout; no external challenger or quality-bar board was obtained. The user's delegated decision is implemented directly in code this session, without recording an unchosen standing build preference.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Interaction and motion

Navigation updates the selected location after LiveView navigation. The mobile drawer opens with a short slide, traps focus, closes with Escape or an action, and restores focus. Theme selection updates charts and editor immediately. Hover and focus use the same 160ms transition grammar; reduced motion disables movement. No delayed application page entrances.

## Implementation plan

1. Replace vendor component styling with project-owned Tailwind tokens and UI primitives. Bundle fonts and preserve the Tailwind v4 source imports.
2. Rebuild the shell, brand, public presentation, authentication, and theme behavior.
3. Apply the vocabulary throughout operational pages; improve editor layout, tables, object lists, dashboard controls, and empty states.
4. Update Chart.js and CodeMirror themes. Verify permissions and existing flows with the full suite, coverage, integration, and bounded desktop/mobile browser passes.
5. Run the Impeccable detector once, obtain an independent finish review, resolve material findings, and document the shipped design system.

## Review constraints

No invented clients, testimonials, deployment claims, or metrics. Sample values on the home page are labeled as an example. Existing backend behavior remains authoritative. No frontend framework migration or new runtime dependencies.

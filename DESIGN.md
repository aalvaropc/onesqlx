---
name: OneSQLx
description: A precise analytical atlas for SQL and shared understanding.
colors:
  canvas: '#f4f7f6'
  surface: '#ffffff'
  surface-raised: '#ffffff'
  ink: '#1b302b'
  muted: '#60716b'
  line: '#dce5e0'
  accent: '#087f68'
  accent-hover: '#066852'
  accent-ink: '#ffffff'
  accent-soft: '#e4f3ec'
  info: '#316c9c'
  success: '#147453'
  warning: '#8c5c13'
  error: '#ba3e45'
  sidebar: '#132d27'
  sidebar-ink: '#d5e5dd'
  sidebar-muted: '#a0b8ad'
  focus: '#1a967d'
  chart-grid: '#e5ece8'
  chart-1: '#07866e'
  chart-2: '#789776'
  chart-3: '#ddac5d'
  chart-4: '#718ec5'
  chart-5: '#ba7c80'
  chart-6: '#7f799e'
  overlay: rgb(10 25 20 / 55%)
  dark-canvas: '#111c19'
  dark-surface: '#192621'
  dark-surface-raised: '#20322a'
  dark-ink: '#e5eee8'
  dark-muted: '#a1b3a8'
  dark-line: '#304339'
  dark-accent: '#7dd3ab'
  dark-accent-hover: '#a5e6c6'
  dark-accent-ink: '#102c20'
  dark-accent-soft: '#213e30'
  dark-info: '#8dbce6'
  dark-success: '#7dd3ab'
  dark-warning: '#e5bd7a'
  dark-error: '#f0a0a2'
  dark-sidebar: '#0c1713'
  dark-sidebar-ink: '#d5e5dd'
  dark-sidebar-muted: '#96b1a2'
  dark-focus: '#7dd3ab'
  dark-chart-grid: '#304339'
  dark-chart-1: '#7dd3ab'
  dark-chart-2: '#a8c68f'
  dark-chart-3: '#e3b773'
  dark-chart-4: '#93b3e9'
  dark-chart-5: '#e0a0a5'
  dark-chart-6: '#b1a4d2'
  dark-overlay: rgb(0 10 5 / 70%)
  forest: '#143e30'
  forest-copy: '#c3d9cb'
  brand-mint: '#a6ddbd'
typography:
  display:
    fontFamily: '"Red Hat Display", "Red Hat Text", sans-serif'
    fontSize: clamp(44px, 4.8vw, 70px)
    fontWeight: 700
    lineHeight: 1.05
    letterSpacing: -.035em
  headline:
    fontFamily: '"Red Hat Display", "Red Hat Text", sans-serif'
    fontSize: 36px
    lineHeight: 1.15
    letterSpacing: -.03em
  auth-headline:
    fontFamily: '"Red Hat Display", "Red Hat Text", sans-serif'
    fontSize: 42px
    lineHeight: 1.15
    letterSpacing: -.03em
  title:
    fontFamily: '"Red Hat Text", ui-sans-serif, sans-serif'
    fontSize: 26px
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: -.03em
  panel-title:
    fontFamily: '"Red Hat Text", ui-sans-serif, sans-serif'
    fontSize: 16px
    fontWeight: 600
  body:
    fontFamily: '"Red Hat Text", ui-sans-serif, sans-serif'
    fontSize: 14px
    fontWeight: 400
    lineHeight: 1.55
  label:
    fontFamily: '"Red Hat Text", ui-sans-serif, sans-serif'
    fontSize: 12px
    fontWeight: 500
  code:
    fontFamily: '"Source Code Pro", ui-monospace, monospace'
    fontSize: 12px
    fontWeight: 400
    lineHeight: 2
  metric:
    fontFamily: '"Red Hat Text", ui-sans-serif, sans-serif'
    fontSize: 28px
    fontWeight: 600
    letterSpacing: -.03em
rounded:
  badge: 5px
  control: 7px
  menu: 8px
  notice: 9px
  workbench: 10px
  panel: 12px
  auth: 16px
  hero: 18px
spacing:
  tight: 4px
  control-gap: 8px
  compact: 12px
  section: 16px
  roomy: 20px
  panel: 24px
  page: 32px
  public: 40px
components:
  button-neutral:
    backgroundColor: '{colors.surface}'
    textColor: '{colors.ink}'
    rounded: '{rounded.control}'
    padding: 8px 14px
    height: 36px
  button-primary:
    backgroundColor: '{colors.accent}'
    textColor: '{colors.accent-ink}'
    rounded: '{rounded.control}'
    padding: 8px 14px
    height: 36px
  button-primary-hover:
    backgroundColor: '{colors.accent-hover}'
  button-soft:
    backgroundColor: '{colors.accent-soft}'
    textColor: '{colors.accent}'
    rounded: '{rounded.control}'
    padding: 8px 14px
  button-ghost:
    backgroundColor: transparent
    textColor: '{colors.ink}'
    rounded: '{rounded.control}'
    padding: 8px 14px
  button-outline:
    backgroundColor: transparent
    textColor: '{colors.ink}'
    rounded: '{rounded.control}'
    padding: 8px 14px
  button-error:
    backgroundColor: color-mix(in srgb, var(--error) 8%, var(--surface))
    textColor: '{colors.error}'
    rounded: '{rounded.control}'
    padding: 8px 14px
  input:
    backgroundColor: '{colors.surface}'
    textColor: '{colors.ink}'
    rounded: '{rounded.control}'
    padding: 9px 11px
    height: 39px
    width: 100%
  panel:
    backgroundColor: '{colors.surface}'
    rounded: '{rounded.panel}'
    padding: 24px
  badge:
    backgroundColor: '{colors.canvas}'
    textColor: '{colors.muted}'
    rounded: '{rounded.badge}'
    padding: 3px 8px
  badge-success:
    backgroundColor: '{colors.accent-soft}'
    textColor: '{colors.success}'
    rounded: '{rounded.badge}'
    padding: 3px 8px
  navigation:
    backgroundColor: '{colors.sidebar}'
    textColor: '{colors.sidebar-ink}'
    rounded: '{rounded.control}'
    padding: 10px 12px
  results-table:
    backgroundColor: '{colors.surface}'
    textColor: '{colors.ink}'
    rounded: '{rounded.panel}'
  button-neutral-dark:
    backgroundColor: '{colors.dark-surface}'
    textColor: '{colors.dark-ink}'
    rounded: '{rounded.control}'
    padding: 8px 14px
    height: 36px
  button-primary-dark:
    backgroundColor: '{colors.dark-accent}'
    textColor: '{colors.dark-accent-ink}'
    rounded: '{rounded.control}'
    padding: 8px 14px
    height: 36px
  button-primary-hover-dark:
    backgroundColor: '{colors.dark-accent-hover}'
  button-soft-dark:
    backgroundColor: '{colors.dark-accent-soft}'
    textColor: '{colors.dark-accent}'
    rounded: '{rounded.control}'
    padding: 8px 14px
  button-ghost-dark:
    backgroundColor: transparent
    textColor: '{colors.dark-ink}'
    rounded: '{rounded.control}'
    padding: 8px 14px
  button-outline-dark:
    backgroundColor: transparent
    textColor: '{colors.dark-ink}'
    rounded: '{rounded.control}'
    padding: 8px 14px
  button-error-dark:
    backgroundColor: color-mix(in srgb, var(--error) 8%, var(--surface))
    textColor: '{colors.dark-error}'
    rounded: '{rounded.control}'
    padding: 8px 14px
  input-dark:
    backgroundColor: '{colors.dark-surface}'
    textColor: '{colors.dark-ink}'
    rounded: '{rounded.control}'
    padding: 9px 11px
    height: 39px
    width: 100%
  panel-dark:
    backgroundColor: '{colors.dark-surface}'
    rounded: '{rounded.panel}'
    padding: 24px
  badge-dark:
    backgroundColor: '{colors.dark-canvas}'
    textColor: '{colors.dark-muted}'
    rounded: '{rounded.badge}'
    padding: 3px 8px
  badge-success-dark:
    backgroundColor: '{colors.dark-accent-soft}'
    textColor: '{colors.dark-success}'
    rounded: '{rounded.badge}'
    padding: 3px 8px
  navigation-dark:
    backgroundColor: '{colors.dark-sidebar}'
    textColor: '{colors.dark-sidebar-ink}'
    rounded: '{rounded.control}'
    padding: 10px 12px
  results-table-dark:
    backgroundColor: '{colors.dark-surface}'
    textColor: '{colors.dark-ink}'
    rounded: '{rounded.panel}'
---

# Design System: OneSQLx

<!-- Extracted from assets/css/app.css; lib/onesqlx_web/components/layouts.ex; lib/onesqlx_web/components/core_components.ex; lib/onesqlx_web/controllers/page_html/home.html.heex; assets/js/theme.js; assets/js/hooks/chart_card.js. Source code is authoritative. This is a shipped-system scan, not a whole-surface approval. -->

## Overview

**Creative North Star: "The Analytical Atlas"**

OneSQLx pairs mineral green actions with graphite navigation and cool working surfaces. It feels precise and approachable: analytical content carries the interface, while restrained borders distinguish tools, results, and context. Light and dark modes retain the same hierarchy.

The public and authentication surfaces use a shared forest field and expressive Red Hat Display headlines. Inside the application, Red Hat Text supports compact controls and tables; Source Code Pro identifies SQL. This is the implemented replacement world, with product demonstrations built from code rather than generated bitmap decoration.

**Key Characteristics:**

- Mineral green actions and forest brand fields.
- Compact controls, generous panel spacing, restrained dividers.
- A persistent analytical workspace on desktop and a dialog drawer on mobile.
- Self-hosted display, UI, and code typography.
- Theme-aware charts and consistent visible focus.

## Colors

Mineral green carries actions; deep forest anchors navigation and brand storytelling. Neutrals make code, tables, and charts readable without decorative competition. Frontmatter contains the normative light tokens and their `dark-` siblings; runtime CSS uses the same semantic variable names in both modes.

### Primary

- **Mineral Green** (`accent`, `accent-hover`, `accent-ink`): filled actions, links, active tabs, text selection, and their readable foregrounds.
- **Pale Mineral** (`accent-soft`): selected controls, success badges, and quiet action backgrounds.
- **Forest** (`forest`) with **Forest Copy** (`forest-copy`): shared public and authentication storytelling fields; these retain their forest treatment in both themes.
- **Brand Mint** (`brand-mint`): the sidebar brand mark and wordmark accent.

### Secondary

- **Status colors** (`info`, `success`, `warning`, `error`): semantic notices, field errors, and status badges. Their background tints are derived in CSS from the relevant status variable.
- **Chart categories** (`chart-1` through `chart-6`): mineral, sage, amber, slate blue, dusty rose, and violet series. Use the sequence consistently; it changes to lighter counterparts in dark mode.

### Neutral

- **Canvas**, **Surface**, and **Raised Surface**: page ground, working panels, and floating menus/tooltips.
- **Ink**, **Muted**, and **Line**: primary text, supporting text, and fine separators.
- **Sidebar**, **Sidebar Ink**, and **Sidebar Muted**: a dark navigation field in both themes.
- **Chart Grid**: quiet chart reference lines. **Overlay**: dialog backdrop. **Focus**: keyboard focus indication.

**The Working Surface Rule.** Use semantic surface, ink, line, and accent variables so light and dark modes keep the same hierarchy.

## Typography

**Display Font:** Red Hat Display, with Red Hat Text and sans-serif fallbacks.
**Body Font:** Red Hat Text, with ui-sans-serif and sans-serif fallbacks.
**Label/Mono Font:** Source Code Pro, with ui-monospace and monospace fallbacks.

**Character:** Broad, confident public headlines give way to compact, calm interface typography. All three families are bundled in `priv/static/fonts`; body weights are 400, 500, 600, and 700, display uses its supplied bold face, and code uses regular.

### Hierarchy

- **Display:** the frontmatter display role governs the public hero. Mobile explicitly uses (46px), with a measure of (13ch); desktop uses (12ch).
- **Headline:** public detail headings use the headline role, becoming (32px) on mobile. Authentication uses its own larger headline role, becoming (30px) on mobile.
- **Title:** operational page titles use the title role, becoming (23px) on mobile. Authentication form titles use (25px).
- **Panel title:** identifies sections within working panels; compact dashboard chart headings use (13px, 600).
- **Body:** the body role supplies defaults. Supporting operational copy uses (13px) and a maximum measure of (68ch); long prose uses (70ch) and line-height (1.75).
- **Label:** labels and buttons use the label role; table headings and compact badges use (11px). Navigation group labels are functional uppercase section names, not a marketing eyebrow pattern.
- **Code:** the code role is observed in authentication SQL; the public SQL illustration uses (11px) and (9px) on mobile. Numeric tables and dashboard metrics use tabular numerals.

**The Three Voices Rule.** Use Red Hat Display for expressive public headlines, Red Hat Text for the interface, and Source Code Pro for SQL.

## Layout

The desktop application is a viewport-height flex workspace: a fixed (240px) navigation column, a (65px) top bar, and a scrolling main region with (32px) padding. Ordinary content is centered at a maximum width of (1200px); the editor can use the wide-content mode.

Below (768px), navigation becomes a native dialog drawer sized to `min(300px, 86vw)`, the top bar becomes (61px), and the main padding becomes (24px 16px). Location text truncates while action controls retain their space. Dialog close, Escape, and navigation actions use native dialog behavior and the bundled theme/navigation module.

The public frame has a (1280px) header/footer and a (1440px) outer content maximum. Its forest hero uses a two-column (.95fr / 1.25fr) composition, then stacks below (768px). The authentication frame is two equal columns with a compact single-column mobile treatment. These are surface-specific compositions, not mandatory application grids.

The SQL workbench keeps connection controls, editor, and results together. Its history rail is (240px), narrows to (210px) at the (1100px) adaptation, and moves below the main work area at (1023px). Editor height uses `clamp(200px, 30vh, 380px)`. Toolbars wrap; data containers scroll horizontally. Dashboard metrics use two columns on mobile and four from (768px).

Spacing is contextual rather than a strict arithmetic scale. The frontmatter records recurring steps from the source; smaller icon/control gaps and larger public composition offsets remain local. Shared dashboards use a centered (1280px) maximum with (16px) mobile and (32px) desktop horizontal padding; embeds use (16px) padding.

## Elevation & Depth

The interface uses a hybrid: fine borders and tonal layering for analytical surfaces, ambient shadows for floating UI, and one deliberately lifted product illustration on the public forest field. No hard offset shadow vocabulary is established.

### Shadow Vocabulary

- **Floating:** the CSS `--elevation` token is used by dropdowns and toast notices; its light and dark values are recorded in the sidecar.
- **Selected theme control:** a small (0 1px 3px #00000012) lift marks the chosen theme preference.
- **Product illustration:** (0 26px 60px rgb(0 12 5 / 25%)) anchors the public demonstration; its desktop rotation is removed on mobile.

**The Resting Panel Rule.** Working panels are flat at rest; dividers and tonal surfaces do the organizing. Reserve ambient shadows for floating controls and notices.

## Shapes

Controls use softly squared corners; panels are more open. The normative radius roles are in the frontmatter: badges, controls, menus, notices, workbench frames, panels, authentication, and the public hero each have an observed role. The hero radius tightens to (14px) on mobile. Most structure uses a single fine border; empty states use a dashed outline. Circles are reserved for compact active dots, chart legend marks, and loading indicators.

## Components

### Buttons

Compact, familiar controls with a clear action hierarchy. The default control uses a thin line border, the control radius, and label typography. The primary variant uses mineral green and its readable foreground; soft uses a pale mineral fill; ghost removes the resting border and background; outline retains a border with transparent fill; destructive actions use a faint error tint.

Background, border, color, and shadow transitions use (160ms ease-out). Keyboard focus uses the shared focus color with a (2px) outline and (3px) offset. Disabled controls use (.5) opacity and suppress interaction. Small, extra-small, and large controls are observed at minimum heights of (31px), (25px), and (46px). Frontmatter component `height` records the default minimum height, not a fixed height. The Phoenix button helper defaults to the soft combination; explicitly choosing its primary variant produces a filled action.

### Chips

Small, compact rectangular badges carry status or metadata. Default badges use canvas and muted text; success/primary badges use the mineral tint and success text. Warning, error, and info derive a (10%) status tint from the surface. Outline badges are transparent with a fine line border; chips are not implicitly interactive controls.

### Cards / Containers

Working panels use the surface background, panel radius, fine line border, and (24px) internal padding. Object rows gently change border color on hover. Dashboard cards use (22px) padding and (16px) on mobile; metric groups share dividers rather than separate floating cards. Empty states are spacious, dashed containers with a compact semantic icon and a next action.

### Inputs / Fields

Surface-backed controls use a fine line border, control radius, and the input token padding. Focus changes the border to accent and adds a (2px) outline using an (18%) accent mix with a (1px) offset. Errors use the error border and an adjacent message; disabled fields use canvas and (.6) opacity. Labels sit above fields. Selects preserve room for their native indicator; textareas resize vertically and begin at (90px) minimum height.

### Navigation

The dark sidebar groups Explore, Observe, and Workspace. Links use (12px) UI text, compact semantic icons, soft rectangular hover fills, and an active mineral tint plus a small dot. The source module keeps `aria-current="page"` synchronized after LiveView navigation. Long account/workspace names truncate. On mobile the same content appears in the dialog drawer, with an explicit close action.

### Tables and SQL results

Tables use (12px) body text and (11px) headings, tabular numerals, fine horizontal dividers, and a very faint mineral row hover. Default cell padding is (13px 16px); heading padding is (12px 16px); mobile tightens both to (10px 12px). Results stay in scrollable bordered frames. Tabs identify the active view with accent text and a fine bottom rule.

### Theme control and analytical charts

A compact three-part group exposes system, light, and dark preferences using `aria-pressed`. The chosen segment uses surface, accent text, and the small selected-control shadow. Explicit preferences persist in local storage; system mode follows the OS; cross-tab changes and LiveView navigation synchronize the controls.

Charts read the six category variables, ink/muted/line/surface tokens, and chart-grid token from the active theme. Tooltips use raised surfaces with a line border and (8px) corners. Chart animation lasts (220ms), becoming disabled for reduced motion; bars use (4px) corners, line points grow from (2px) to (5px) on hover, and area fill uses the series color with hexadecimal alpha `26`. Global reduced motion reduces transitions and animations to (.01ms); the drawer otherwise slides over (180ms). Spinner and skeleton motion remain functional loading states.

## Do's and Don'ts

### Do:

- **Do** use the shared semantic variables for operational surfaces and charts.
- **Do** preserve the visible focus ring and active navigation state.
- **Do** let toolbars wrap and tables scroll horizontally on narrow screens.
- **Do** keep SQL and its results together and label illustrative example data.
- **Do** respect reduced motion and keep state changes immediate.

### Don't:

- **Don't** substitute remote fonts or bitmap mockups for the bundled fonts and code-built product demonstration.
- **Don't** add ambient shadows to every analytical panel.
- **Don't** use the chart category palette as an alternate action palette.
- **Don't** turn public hero composition or a sample data value into a rule for all application screens.

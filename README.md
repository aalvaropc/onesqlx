# OneSQLx

Plataforma de analítica open source, SQL-first, construida con Elixir y Phoenix. Conecta bases de datos PostgreSQL externas para explorar schemas, ejecutar queries read-only, guardar consultas, construir dashboards y automatizar tareas en background.

- **SQL-first**: el SQL es una capacidad central, no algo secundario.
- **PostgreSQL-first**: el MVP se enfoca en hacer muy bien una sola integración.
- **Open source**: el producto busca ser útil, transparente y extensible.
- **Workspace-based**: el conocimiento analítico pertenece a equipos y workspaces.
- **Automation-ready**: usa Oban para tareas confiables en segundo plano.

## MVP

La primera versión de OneSQLx incluirá:

- autenticación de usuarios,
- workspaces con membresías y roles,
- conexión a bases de datos PostgreSQL externas,
- sincronización de catálogo (schemas, tablas, columnas),
- exploración visual del catálogo,
- SQL editor con ejecución de queries read-only,
- saved queries con organización por workspace,
- dashboards básicos con paneles y visualizaciones,
- ejecución programada de queries vía Oban,
- auditoría y métricas básicas de uso.

## Stack tecnológico

| Tecnología | Uso |
|---|---|
| Elixir | Lenguaje principal |
| Erlang/OTP | Plataforma de ejecución |
| Phoenix 1.8 | Framework web |
| Phoenix LiveView 1.1 | UI en tiempo real, server-rendered |
| Ecto | ORM y migraciones (base interna) |
| Postgrex | Conexión directa a PostgreSQL externo |
| Oban | Jobs en background |
| PostgreSQL 17 | Base de datos interna y externas |
| Tailwind CSS v4 + DaisyUI | Estilos y componentes UI |
| Req | Cliente HTTP |
| Credo | Análisis estático de código |

## Arquitectura inicial

OneSQLx inicia como un **monolito modular**. Esto permite avanzar rápido sin perder orden interno.

Se separan claramente dos mundos:

1. **Base interna del producto** — manejada con Ecto y migraciones. Almacena usuarios, workspaces, queries guardadas, dashboards, configuración de conexiones y auditoría.

2. **Bases PostgreSQL externas conectadas por los usuarios** — accedidas con Postgrex para introspección de catálogo y ejecución controlada de queries read-only.

## Contextos del dominio

El dominio está organizado en 9 contextos bajo `lib/onesqlx/`:

| Contexto | Módulo | Responsabilidad |
|---|---|---|
| Accounts | `Onesqlx.Accounts` | Autenticación y gestión de usuarios |
| Workspaces | `Onesqlx.Workspaces` | Workspaces, membresías y roles |
| DataSources | `Onesqlx.DataSources` | Conexiones a PostgreSQL externo |
| Catalog | `Onesqlx.Catalog` | Metadata sincronizada (schemas, tablas, columnas) |
| Querying | `Onesqlx.Querying` | Ejecución read-only de SQL contra fuentes externas |
| SavedQueries | `Onesqlx.SavedQueries` | Persistencia y organización de queries |
| Dashboards | `Onesqlx.Dashboards` | Dashboards y paneles con visualizaciones |
| Scheduling | `Onesqlx.Scheduling` | Ejecución programada de queries vía Oban |
| Audit | `Onesqlx.Audit` | Tracking de actividad y eventos del sistema |

## Desarrollo local

### Requisitos previos

- Elixir >= 1.15
- Erlang/OTP >= 26
- PostgreSQL 17 (vía Docker o local)
- Node.js (para esbuild/tailwind, instalados automáticamente por Mix)

### Setup

```bash
# 1. Levantar PostgreSQL con Docker
docker-compose up -d

# 2. Instalar dependencias, crear DB, correr migraciones y compilar assets
mix setup

# 3. Iniciar servidor de desarrollo
mix phx.server
```

El servidor estará disponible en [localhost:4000](http://localhost:4000).

### Comandos útiles

| Comando | Descripción |
|---|---|
| `mix setup` | Setup completo (deps, DB, migraciones, assets) |
| `mix phx.server` | Iniciar servidor de desarrollo |
| `mix test` | Ejecutar todos los tests |
| `mix test test/path_test.exs` | Ejecutar un archivo de test específico |
| `mix test --failed` | Re-ejecutar tests que fallaron |
| `mix precommit` | CI local: compile, deps, format, credo, test |
| `mix credo --strict` | Análisis estático con Credo |
| `mix ecto.migrate` | Ejecutar migraciones pendientes |
| `mix ecto.reset` | Borrar y recrear la base de datos |
| `mix ecto.gen.migration nombre` | Generar nueva migración |
| `docker-compose up -d` | Levantar PostgreSQL 17 |

### Variables de entorno

| Variable | Descripción | Default |
|---|---|---|
| `DATABASE_URL` | URL de conexión a PostgreSQL | `postgres://postgres:postgres@localhost/onesqlx_dev` |
| `SECRET_KEY_BASE` | Clave secreta para Phoenix | Generada en `config/dev.exs` |
| `PHX_HOST` | Hostname del servidor | `localhost` |
| `PORT` | Puerto HTTP | `4000` |

### Herramientas de desarrollo

- **LiveDashboard**: `/dev/dashboard` — métricas y observabilidad
- **Mailbox preview**: `/dev/mailbox` — preview de emails (Swoosh test adapter)

## Convenciones

- **binary_id (UUID)** como primary key en todos los schemas Ecto.
- **Scope-based auth**: usar `@current_scope` (nunca `@current_user`). Acceder al usuario vía `@current_scope.user`.
- **Oban** para jobs en background con colas: `default(10)`, `catalog_sync(5)`, `scheduled_queries(10)`, `maintenance(5)`.
- **Tailwind CSS v4** sin `tailwind.config.js`. Componentes custom, no usar los prebuilt de DaisyUI.
- **Req** como cliente HTTP — nunca HTTPoison, Tesla o :httpc.
- **`mix precommit`** obligatorio antes de cada commit. Ejecuta: compile con warnings-as-errors, deps check, format, credo strict y tests.

## Visión a futuro

Después del MVP, OneSQLx podrá evolucionar hacia:

- parámetros en queries,
- dashboards avanzados con más tipos de visualización,
- schedules avanzados con notificaciones,
- caché de resultados,
- observabilidad de uso,
- modelos reutilizables (snippets SQL),
- dashboards as code,
- soporte para múltiples motores de base de datos,
- integraciones externas (Slack, email, webhooks).

## Licencia

Este proyecto es open source.

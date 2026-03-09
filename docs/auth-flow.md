# Flujo de autenticación — OneSQLx

## Resumen

La autenticación fue generada por `phx.gen.auth` (Phoenix 1.8). Usa un modelo
**scope-based** donde `@current_scope` (no `@current_user`) es el assign principal.
El método primario de login es **magic link** (passwordless), con contraseña como
opción secundaria.

## Archivos clave

### Plugs y helpers

- `lib/onesqlx_web/user_auth.ex` — plugs de autenticación:
  - `fetch_current_scope_for_user/2` — carga usuario desde sesión o cookie remember-me
  - `require_authenticated_user/2` — redirige a login si no autenticado
  - `on_mount` callbacks: `:mount_current_scope`, `:require_authenticated`, `:require_sudo_mode`

### LiveViews

| Archivo | Ruta | Propósito |
|---|---|---|
| `live/user_live/registration.ex` | `/users/register` | Registro con email |
| `live/user_live/login.ex` | `/users/log-in` | Login (magic link + password) |
| `live/user_live/confirmation.ex` | `/users/log-in/:token` | Confirmación de magic link |
| `live/user_live/settings.ex` | `/users/settings` | Cambio de email y password |

### Controller

- `controllers/user_session_controller.ex` — maneja POST login, POST update-password, DELETE logout

### Contexto

- `lib/onesqlx/accounts.ex` — funciones de negocio (registro, tokens, sesiones)
- `lib/onesqlx/accounts/user.ex` — schema User con binary_id
- `lib/onesqlx/accounts/user_token.ex` — tokens de sesión y magic link
- `lib/onesqlx/accounts/scope.ex` — modelo Scope que envuelve al usuario
- `lib/onesqlx/accounts/user_notifier.ex` — envío de emails

## Router — live_sessions

```
:current_user (público, auth opcional)
├── /users/register
├── /users/log-in
└── /users/log-in/:token

:require_authenticated_user (protegido)
├── /users/settings
└── /users/settings/confirm-email/:token
```

## Estrategia de tokens

- **Sesión**: token en cookie de sesión, reemitido cada 7 días
- **Remember-me**: cookie `_onesqlx_web_user_remember_me`, 14 días
- **Sudo mode**: requiere autenticación reciente (10 minutos) para operaciones sensibles

## Regla de oro

Nunca usar `@current_user`. Siempre `@current_scope` y acceder al usuario con
`@current_scope.user`. Pasar `current_scope` como primer argumento a funciones de contexto.

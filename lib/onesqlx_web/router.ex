defmodule OnesqlxWeb.Router do
  use OnesqlxWeb, :router

  import OnesqlxWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OnesqlxWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_rate_limit do
    plug OnesqlxWeb.Plugs.RateLimit, max_requests: 100
  end

  pipeline :api_rate_limit_strict do
    plug OnesqlxWeb.Plugs.RateLimit, max_requests: 20
  end

  pipeline :embed do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OnesqlxWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug OnesqlxWeb.Plugs.AllowIframe
    plug :fetch_current_scope_for_user
  end

  # Health check endpoints (unauthenticated)
  scope "/", OnesqlxWeb do
    pipe_through :api

    get "/health", HealthController, :liveness
    get "/ready", HealthController, :readiness
  end

  # OpenAPI documentation (unauthenticated)
  pipeline :api_docs do
    plug :accepts, ["json", "html"]
    plug OpenApiSpex.Plug.PutApiSpec, module: OnesqlxWeb.ApiSpec
  end

  scope "/api" do
    pipe_through :api_docs

    get "/openapi", OpenApiSpex.Plug.RenderSpec, []
    get "/docs", OpenApiSpex.Plug.SwaggerUI, path: "/api/openapi"
  end

  scope "/", OnesqlxWeb do
    pipe_through :browser

    get "/", PageController, :home

    live_session :public, on_mount: [{OnesqlxWeb.UserAuth, :mount_current_scope}] do
      live "/share/:token", DashboardLive.Public, :show
    end
  end

  scope "/", OnesqlxWeb do
    pipe_through :embed

    live_session :embed, on_mount: [{OnesqlxWeb.UserAuth, :mount_current_scope}] do
      live "/embed/:token", DashboardLive.Embed, :show
    end
  end

  pipeline :require_read do
    plug OnesqlxWeb.Plugs.RequireScope, "read"
  end

  pipeline :require_execute do
    plug OnesqlxWeb.Plugs.RequireScope, "execute"
  end

  pipeline :require_manage do
    plug OnesqlxWeb.Plugs.RequireScope, "manage"
  end

  # API: read scope (GET endpoints)
  scope "/api/v1", OnesqlxWeb.Api do
    pipe_through [:api, OnesqlxWeb.Plugs.ApiAuth, :api_rate_limit, :require_read]

    resources "/saved-queries", SavedQueryController, only: [:index, :show]
    resources "/dashboards", DashboardController, only: [:index, :show]
    resources "/schedules", ScheduledQueryController, only: [:index, :show]
    resources "/data-sources", DataSourceController, only: [:index]
  end

  # API: execute scope (query execution)
  scope "/api/v1", OnesqlxWeb.Api do
    pipe_through [:api, OnesqlxWeb.Plugs.ApiAuth, :api_rate_limit_strict, :require_execute]

    post "/saved-queries/:id/execute", SavedQueryController, :execute
  end

  # API: manage scope (create, update, delete)
  scope "/api/v1", OnesqlxWeb.Api do
    pipe_through [:api, OnesqlxWeb.Plugs.ApiAuth, :api_rate_limit, :require_manage]

    resources "/saved-queries", SavedQueryController, only: [:create, :update, :delete]
    resources "/dashboards", DashboardController, only: [:create, :delete]
    resources "/schedules", ScheduledQueryController, only: [:create, :update, :delete]
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:onesqlx, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: OnesqlxWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", OnesqlxWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{OnesqlxWeb.UserAuth, :require_authenticated}] do
      live "/dashboards", DashboardLive.Index, :index
      live "/dashboards/:id", DashboardLive.Show, :show
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/data-sources", DataSourceLive.Index, :index
      live "/data-sources/new", DataSourceLive.New, :new
      live "/data-sources/:data_source_id/catalog", CatalogLive.Explorer, :index
      live "/sql-editor", SqlEditorLive, :index
      live "/saved-queries", SavedQueryLive.Index, :index
      live "/schedules", ScheduledQueryLive.Index, :index
      live "/schedules/:id", ScheduledQueryLive.Show, :show
      live "/analytics", AnalyticsLive, :index
      live "/settings/api-tokens", ApiTokenLive.Index, :index
      live "/workspace/settings", WorkspaceLive.Settings, :edit
    end

    post "/exports/csv", ExportController, :csv
    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", OnesqlxWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{OnesqlxWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete

    get "/auth/:provider", UserOAuthController, :request
    get "/auth/:provider/callback", UserOAuthController, :callback
  end
end

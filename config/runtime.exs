import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/onesqlx start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :onesqlx, OnesqlxWeb.Endpoint, server: true
end

config :onesqlx, OnesqlxWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

# OAuth provider credentials (optional — OAuth buttons hidden if not configured)
if System.get_env("GOOGLE_CLIENT_ID") do
  config :ueberauth, Ueberauth.Strategy.Google.OAuth,
    client_id: System.get_env("GOOGLE_CLIENT_ID"),
    client_secret: System.get_env("GOOGLE_CLIENT_SECRET")
end

if System.get_env("GITHUB_CLIENT_ID") do
  config :ueberauth, Ueberauth.Strategy.Github.OAuth,
    client_id: System.get_env("GITHUB_CLIENT_ID"),
    client_secret: System.get_env("GITHUB_CLIENT_SECRET")
end

# Dedicated key for data source credential encryption (base64, 32 bytes).
# With it configured, rotating SECRET_KEY_BASE no longer invalidates
# stored credentials. Generate with: openssl rand -base64 32
if encoded_key = System.get_env("ENCRYPTION_KEY") do
  key =
    case Base.decode64(encoded_key) do
      {:ok, <<_::binary-size(32)>> = key} -> key
      _ -> raise "ENCRYPTION_KEY must be exactly 32 bytes, base64-encoded"
    end

  config :onesqlx, :encryption_key, key
end

# Sender for all outgoing email (magic links, schedule notifications)
if System.get_env("MAIL_FROM") do
  config :onesqlx,
         :mail_from,
         {System.get_env("MAIL_FROM_NAME", "OneSQLx"), System.get_env("MAIL_FROM")}
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  # TLS to the internal database, opt-in with DATABASE_SSL=true (uses the
  # system CA store). Needed when the database is not on a private network.
  database_ssl =
    if System.get_env("DATABASE_SSL") in ~w(true 1),
      do: [ssl: [cacerts: :public_key.cacerts_get()]],
      else: []

  config :onesqlx,
         Onesqlx.Repo,
         [
           url: database_url,
           pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
           # For machines with several cores, consider starting multiple pools of `pool_size`
           # pool_count: 4,
           socket_options: maybe_ipv6
         ] ++ database_ssl

  # Prometheus /metrics: requires `Authorization: Bearer $METRICS_TOKEN`;
  # without METRICS_TOKEN the endpoint responds 404 (secure by default).
  metrics_auth =
    case System.get_env("METRICS_TOKEN") do
      nil -> :disabled
      "" -> :disabled
      token -> {:token, token}
    end

  config :onesqlx, :metrics_auth, metrics_auth

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :onesqlx, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :onesqlx, OnesqlxWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :onesqlx, OnesqlxWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :onesqlx, OnesqlxWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Mailer
  #
  # Adapter chosen from env vars: SMTP_HOST → SMTP, RESEND_API_KEY → Resend.
  # With neither set the mailer stays on the Local adapter and outgoing
  # email (magic links, schedule notifications) is NOT delivered — the
  # application logs a warning at startup (see Onesqlx.Application).
  case Onesqlx.MailerConfig.resolve(System.get_env()) do
    {adapter, opts} ->
      config :onesqlx, Onesqlx.Mailer, [adapter: adapter] ++ opts
      config :onesqlx, :mailer_configured, true

    :local ->
      config :onesqlx, :mailer_configured, false
  end
end

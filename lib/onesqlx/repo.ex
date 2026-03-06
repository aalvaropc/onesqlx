defmodule Onesqlx.Repo do
  use Ecto.Repo,
    otp_app: :onesqlx,
    adapter: Ecto.Adapters.Postgres
end

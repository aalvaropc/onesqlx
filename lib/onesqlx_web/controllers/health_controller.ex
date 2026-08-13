defmodule OnesqlxWeb.HealthController do
  use OnesqlxWeb, :controller

  alias Onesqlx.Repo

  def liveness(conn, _params) do
    json(conn, %{status: "ok"})
  end

  def readiness(conn, _params) do
    checks = %{
      database: check_database(),
      oban: check_oban()
    }

    all_ok = Enum.all?(checks, fn {_k, v} -> v == :ok end)
    status = if all_ok, do: :ok, else: :service_unavailable

    conn
    |> put_status(status)
    |> json(%{
      status: if(all_ok, do: "ok", else: "degraded"),
      checks: Map.new(checks, fn {k, v} -> {k, to_string(v)} end)
    })
  end

  defp check_database do
    case Repo.query("SELECT 1") do
      {:ok, _} -> :ok
      {:error, _} -> :error
    end
  end

  defp check_oban do
    if oban_testing?() do
      :ok
    else
      # Oban registers its supervisor via Oban.Registry, not as a local
      # name — Process.whereis(Oban) is always nil in a running release
      case Oban.Registry.whereis(Oban) do
        pid when is_pid(pid) -> :ok
        _ -> :error
      end
    end
  end

  defp oban_testing? do
    Application.get_env(:onesqlx, Oban)[:testing] != nil
  end
end

defmodule OnesqlxWeb.Plugs.RateLimit.Store do
  @moduledoc """
  Supervised owner of the rate limit counters.

  Keeps the ETS table alive independently of the request processes that use it.
  """

  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    :ets.new(OnesqlxWeb.Plugs.RateLimit, [:set, :public, :named_table])
    {:ok, %{}}
  end
end

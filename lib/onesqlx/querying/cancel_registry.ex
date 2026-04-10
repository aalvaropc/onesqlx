defmodule Onesqlx.Querying.CancelRegistry do
  @moduledoc """
  ETS-backed registry for tracking cancellable query backend PIDs.

  Allows the SQL editor to cancel running queries by looking up the
  PostgreSQL backend PID associated with a cancel reference.
  """

  use GenServer

  @table :query_cancel_registry

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def register(ref, backend_pid) do
    :ets.insert(@table, {ref, backend_pid})
    :ok
  end

  def lookup(ref) do
    case :ets.lookup(@table, ref) do
      [{^ref, backend_pid}] -> {:ok, backend_pid}
      [] -> :error
    end
  end

  def unregister(ref) do
    :ets.delete(@table, ref)
    :ok
  end

  @impl true
  def init(_) do
    :ets.new(@table, [:named_table, :public, :set])
    {:ok, %{}}
  end
end

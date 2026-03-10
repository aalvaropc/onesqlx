defmodule Onesqlx.Catalog.SyncWorker do
  @moduledoc """
  Oban worker that syncs catalog metadata from an external PostgreSQL database.
  """

  use Oban.Worker, queue: :catalog_sync, max_attempts: 3

  alias Onesqlx.Catalog
  alias Onesqlx.Catalog.PgIntrospector
  alias Onesqlx.DataSources
  alias Onesqlx.DataSources.DataSource
  alias Onesqlx.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"data_source_id" => id}}) do
    data_source = Repo.get!(DataSource, id)

    case PgIntrospector.introspect(data_source) do
      {:ok, data} ->
        {:ok, _} = Catalog.sync_catalog(data_source, data)
        DataSources.update_data_source_status(data_source, "connected")
        :ok

      {:error, reason} ->
        DataSources.update_data_source_status(data_source, "error")
        {:error, reason}
    end
  end

  @doc """
  Enqueues a catalog sync job for the given data source ID.
  """
  def enqueue(data_source_id) do
    %{"data_source_id" => data_source_id}
    |> __MODULE__.new()
    |> Oban.insert()
  end
end

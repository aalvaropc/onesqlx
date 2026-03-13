defmodule Onesqlx.Catalog.PgIntrospector do
  @moduledoc """
  Introspects external PostgreSQL databases to discover schemas, tables, and columns.

  Returns structured data suitable for `Catalog.sync_catalog/2`.
  """

  alias Onesqlx.DataSources.Connection
  alias Onesqlx.DataSources.DataSource

  @doc """
  Introspects a data source and returns its schema metadata.

  Returns `{:ok, %{schemas: [...], tables: [...], columns: [...]}}` or `{:error, reason}`.
  """
  def introspect(%DataSource{} = data_source) do
    Connection.impl().with_connection(data_source, fn conn ->
      with {:ok, schemas} <- fetch_schemas(conn),
           {:ok, tables} <- fetch_tables(conn),
           {:ok, columns} <- fetch_columns(conn) do
        {:ok, %{schemas: schemas, tables: tables, columns: columns}}
      end
    end)
  end

  defp fetch_schemas(conn) do
    query = """
    SELECT schema_name
    FROM information_schema.schemata
    WHERE schema_name NOT LIKE 'pg_%'
      AND schema_name != 'information_schema'
    ORDER BY schema_name
    """

    case Postgrex.query(conn, query, []) do
      {:ok, %{rows: rows}} ->
        {:ok, Enum.map(rows, fn [name] -> name end)}

      {:error, error} ->
        {:error, "Failed to fetch schemas: #{Exception.message(error)}"}
    end
  end

  defp fetch_tables(conn) do
    query = """
    SELECT t.table_schema, t.table_name, t.table_type,
           COALESCE(c.reltuples::bigint, 0) AS estimated_row_count
    FROM information_schema.tables t
    LEFT JOIN pg_catalog.pg_class c ON c.relname = t.table_name
    LEFT JOIN pg_catalog.pg_namespace n ON n.nspname = t.table_schema AND c.relnamespace = n.oid
    WHERE t.table_schema NOT LIKE 'pg_%'
      AND t.table_schema != 'information_schema'
    UNION ALL
    SELECT n.nspname, c.relname, 'MATERIALIZED VIEW', COALESCE(c.reltuples::bigint, 0)
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
    WHERE c.relkind = 'm'
      AND n.nspname NOT LIKE 'pg_%'
      AND n.nspname != 'information_schema'
    ORDER BY 1, 2
    """

    case Postgrex.query(conn, query, []) do
      {:ok, %{rows: rows}} ->
        tables =
          Enum.map(rows, fn [schema, name, table_type, row_count] ->
            %{
              schema: schema,
              name: name,
              table_type: table_type,
              estimated_row_count: row_count
            }
          end)

        {:ok, tables}

      {:error, error} ->
        {:error, "Failed to fetch tables: #{Exception.message(error)}"}
    end
  end

  defp fetch_columns(conn) do
    query = """
    SELECT c.table_schema, c.table_name, c.column_name, c.data_type,
           c.ordinal_position, c.is_nullable = 'YES' AS is_nullable,
           c.column_default, c.character_maximum_length,
           CASE WHEN pk.column_name IS NOT NULL THEN true ELSE false END AS is_primary_key
    FROM information_schema.columns c
    LEFT JOIN (
      SELECT kcu.table_schema, kcu.table_name, kcu.column_name
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
      WHERE tc.constraint_type = 'PRIMARY KEY'
    ) pk ON c.table_schema = pk.table_schema
        AND c.table_name = pk.table_name
        AND c.column_name = pk.column_name
    WHERE c.table_schema NOT LIKE 'pg_%'
      AND c.table_schema != 'information_schema'
    ORDER BY c.table_schema, c.table_name, c.ordinal_position
    """

    case Postgrex.query(conn, query, []) do
      {:ok, %{rows: rows}} ->
        columns =
          Enum.map(rows, fn [schema, table, name, data_type, pos, nullable, default, max_len, pk] ->
            %{
              schema: schema,
              table: table,
              name: name,
              data_type: data_type,
              ordinal_position: pos,
              is_nullable: nullable,
              column_default: default,
              is_primary_key: pk,
              character_maximum_length: max_len
            }
          end)

        {:ok, columns}

      {:error, error} ->
        {:error, "Failed to fetch columns: #{Exception.message(error)}"}
    end
  end
end

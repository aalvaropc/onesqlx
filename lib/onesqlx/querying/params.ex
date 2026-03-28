defmodule Onesqlx.Querying.Params do
  @moduledoc """
  Extracts and substitutes named parameters in SQL queries.

  Parameters use the `:param_name` syntax. They are extracted, presented to
  the user for input, and safely substituted as PostgreSQL positional
  parameters ($1, $2, ...).
  """

  @param_regex ~r/(?<!:):([a-zA-Z_][a-zA-Z0-9_]*)/

  @doc """
  Returns `true` if the SQL contains any named parameters.
  """
  @spec parameterized?(String.t()) :: boolean()
  def parameterized?(sql) when is_binary(sql) do
    extract(sql) != []
  end

  @doc """
  Extracts unique parameter names from SQL text, in order of first appearance.

  Ignores parameters inside string literals and PostgreSQL cast syntax (`::type`).
  """
  @spec extract(String.t()) :: [String.t()]
  def extract(sql) when is_binary(sql) do
    stripped = strip_string_literals(sql)

    @param_regex
    |> Regex.scan(stripped, capture: :all_but_first)
    |> List.flatten()
    |> Enum.uniq()
  end

  @doc """
  Substitutes named parameters with positional ($N) parameters.

  Returns `{transformed_sql, ordered_values}` ready for `Postgrex.query/4`.
  Raises `ArgumentError` if a required parameter value is missing.
  """
  @spec substitute(String.t(), %{String.t() => term()}) :: {String.t(), [term()]}
  def substitute(sql, values) when is_binary(sql) and is_map(values) do
    param_names = extract(sql)

    ordered_values =
      Enum.map(param_names, fn name ->
        case Map.fetch(values, name) do
          {:ok, val} -> val
          :error -> raise ArgumentError, "missing value for parameter :#{name}"
        end
      end)

    index_map =
      param_names
      |> Enum.with_index(1)
      |> Map.new()

    transformed =
      Regex.replace(@param_regex, sql, fn full_match, name ->
        case Map.get(index_map, name) do
          nil -> full_match
          idx -> "$#{idx}"
        end
      end)

    {transformed, ordered_values}
  end

  defp strip_string_literals(sql) do
    Regex.replace(~r/'[^']*'/, sql, "''")
  end
end

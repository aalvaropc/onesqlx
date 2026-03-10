defmodule Onesqlx.Querying.SqlGuard do
  @moduledoc """
  Validates SQL statements to block dangerous write operations.

  Provides a safety layer that rejects INSERT, UPDATE, DELETE, ALTER, DROP,
  TRUNCATE, and COPY statements before they reach the database. Handles edge
  cases like CTEs with write operations, multi-statement queries, and keywords
  inside string literals or comments.
  """

  @blocked_commands ~w(INSERT UPDATE DELETE ALTER DROP TRUNCATE COPY)

  @doc """
  Validates that a SQL string contains only read-only statements.

  Returns `:ok` if safe, or `{:error, message}` if a blocked command is found.
  """
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(sql) when is_binary(sql) do
    sanitized = sql |> strip_string_literals() |> strip_comments()

    sanitized
    |> split_statements()
    |> Enum.reduce_while(:ok, fn statement, :ok ->
      case check_statement(statement) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  def validate(_), do: {:error, "SQL must be a string"}

  @doc """
  Returns `true` if the SQL contains only read-only statements.
  """
  @spec safe?(String.t()) :: boolean()
  def safe?(sql) do
    validate(sql) == :ok
  end

  # Strip single-quoted string literals, replacing with a placeholder
  defp strip_string_literals(sql) do
    Regex.replace(~r/'(?:[^']|'')*'/s, sql, "'__LITERAL__'")
  end

  # Strip SQL comments (-- line comments and /* */ block comments)
  defp strip_comments(sql) do
    sql = Regex.replace(~r{/\*.*?\*/}s, sql, " ")
    Regex.replace(~r{--[^\n]*}, sql, " ")
  end

  defp split_statements(sql) do
    sql
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp check_statement(statement) do
    # Extract the first keyword after any WITH...AS(...) CTE prefix
    effective_sql = strip_cte_prefix(statement)
    first_keyword = extract_first_keyword(effective_sql)

    if first_keyword in @blocked_commands do
      {:error, "#{first_keyword} statements are not allowed"}
    else
      :ok
    end
  end

  # Strip WITH...AS(...) CTE prefix to find the actual command keyword.
  # Handles nested parentheses in CTE definitions.
  defp strip_cte_prefix(sql) do
    if String.match?(sql, ~r/\AWITH\b/i) do
      strip_cte_body(sql)
    else
      sql
    end
  end

  # Remove WITH clause(s) to find the final statement keyword.
  # Walks through balanced parentheses to skip CTE bodies.
  defp strip_cte_body(sql) do
    # Remove the leading WITH keyword
    rest = Regex.replace(~r/\AWITH\s+/i, sql, "")
    skip_cte_definitions(rest)
  end

  defp skip_cte_definitions(sql) do
    # Match: identifier AS (...)  [, identifier AS (...)]* final_statement
    # Skip past balanced parens for each CTE definition
    case skip_one_cte(sql) do
      {:ok, rest} ->
        trimmed = String.trim_leading(rest)

        if String.starts_with?(trimmed, ",") do
          trimmed |> String.trim_leading(",") |> String.trim_leading() |> skip_cte_definitions()
        else
          trimmed
        end

      :error ->
        sql
    end
  end

  defp skip_one_cte(sql) do
    # Match: identifier [optional column list] AS (
    case Regex.run(~r/\A\s*\w+\s+AS\s*\(/is, sql) do
      [match] ->
        # Find the matching closing paren
        rest_after_open = String.slice(sql, String.length(match)..-1//1)
        skip_balanced_parens(rest_after_open, 1)

      nil ->
        :error
    end
  end

  defp skip_balanced_parens(<<?(, rest::binary>>, depth),
    do: skip_balanced_parens(rest, depth + 1)

  defp skip_balanced_parens(<<?), rest::binary>>, 1), do: {:ok, rest}

  defp skip_balanced_parens(<<?), rest::binary>>, depth),
    do: skip_balanced_parens(rest, depth - 1)

  defp skip_balanced_parens(<<_, rest::binary>>, depth), do: skip_balanced_parens(rest, depth)
  defp skip_balanced_parens(<<>>, _depth), do: :error

  defp extract_first_keyword(sql) do
    sql
    |> String.trim()
    |> String.split(~r/[\s(]+/, parts: 2)
    |> List.first("")
    |> String.upcase()
  end
end

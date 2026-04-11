defmodule Onesqlx.Querying.SqlFormatter do
  @moduledoc """
  Basic SQL formatter that uppercases keywords and adds line breaks at major clauses.
  """

  @major_clauses ~w(SELECT FROM WHERE JOIN INNER LEFT RIGHT FULL CROSS ON AND OR GROUP ORDER HAVING LIMIT OFFSET UNION INTERSECT EXCEPT WITH AS SET VALUES INSERT UPDATE DELETE INTO RETURNING)
  @indent "  "

  @doc """
  Formats a SQL string with uppercased keywords and clause-level line breaks.
  """
  @spec format(String.t()) :: String.t()
  def format(sql) when is_binary(sql) do
    sql
    |> normalize_whitespace()
    |> uppercase_keywords()
    |> break_clauses()
    |> indent_subclauses()
    |> String.trim()
  end

  def format(sql), do: sql

  defp normalize_whitespace(sql) do
    Regex.replace(~r/\s+/, sql, " ")
  end

  defp uppercase_keywords(sql) do
    pattern = @major_clauses |> Enum.map_join("|", &Regex.escape/1)
    regex = Regex.compile!("\\b(#{pattern})\\b", "i")

    Regex.replace(regex, sql, fn _, match ->
      String.upcase(match)
    end)
  end

  defp break_clauses(sql) do
    top_clauses =
      ~w(SELECT FROM WHERE GROUP ORDER HAVING LIMIT OFFSET UNION INTERSECT EXCEPT WITH INSERT UPDATE DELETE SET VALUES RETURNING)

    Enum.reduce(top_clauses, sql, fn clause, acc ->
      Regex.replace(~r/\s+\b(#{Regex.escape(clause)})\b/i, acc, "\n\\1")
    end)
  end

  defp indent_subclauses(sql) do
    sub_clauses = ~w(JOIN INNER LEFT RIGHT FULL CROSS AND OR ON)

    Enum.reduce(sub_clauses, sql, fn clause, acc ->
      Regex.replace(~r/\n?\s*\b(#{Regex.escape(clause)})\b/i, acc, "\n#{@indent}\\1")
    end)
  end
end

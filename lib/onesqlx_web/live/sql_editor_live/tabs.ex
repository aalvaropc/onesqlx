defmodule OnesqlxWeb.SqlEditorLive.Tabs do
  @moduledoc """
  Pure helpers for the SQL editor's tab state: the shape of a fresh tab
  and the bookkeeping when closing one. All socket plumbing stays in
  `OnesqlxWeb.SqlEditorLive`.
  """

  @default_row_limit 1000

  @doc "Builds a fresh tab map with the given display name."
  def new(name) do
    %{
      id: Ecto.UUID.generate(),
      name: name,
      sql: "",
      data_source_id: nil,
      result: nil,
      error: nil,
      running?: false,
      active_result_tab: :results,
      explain_plan: nil,
      explain_error: nil,
      param_values: %{},
      query_params: [],
      show_params_form?: false,
      execute_sql: "",
      timeout_ref: nil,
      cancel_ref: nil,
      sort_column: nil,
      sort_direction: :asc,
      row_limit: @default_row_limit
    }
  end

  @doc """
  The tab that becomes active after closing `closing_id`: the one at the
  closed tab's position (or the new last tab), unless a different tab
  was already active — that one stays.
  """
  def next_active_after_close(tab_order, active_tab_id, closing_id) do
    if active_tab_id == closing_id do
      remaining = Enum.reject(tab_order, &(&1 == closing_id))
      idx = Enum.find_index(tab_order, &(&1 == closing_id))
      Enum.at(remaining, min(idx, length(remaining) - 1))
    else
      active_tab_id
    end
  end
end

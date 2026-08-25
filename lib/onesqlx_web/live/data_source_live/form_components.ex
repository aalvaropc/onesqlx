defmodule OnesqlxWeb.DataSourceLive.FormComponents do
  @moduledoc """
  The connection form fields shared by the New and Edit data source
  views. Markup only — events stay in the LiveViews.
  """

  use OnesqlxWeb, :html

  attr :form, :any, required: true
  attr :mode, :atom, required: true, values: [:new, :edit]

  def connection_fields(assigns) do
    ~H"""
    <.input field={@form[:name]} type="text" label="Name" required />
    <.input field={@form[:host]} type="text" label="Host" required />
    <.input field={@form[:port]} type="number" label="Port" required />
    <.input field={@form[:database_name]} type="text" label="Database Name" required />
    <.input field={@form[:username]} type="text" label="Username" required />
    <.input
      field={@form[:password]}
      type="password"
      label={if @mode == :edit, do: "Password (leave blank to keep current)", else: "Password"}
      required={@mode == :new}
    />
    <.input field={@form[:ssl_enabled]} type="checkbox" label="Enable SSL" />
    <.input field={@form[:read_only]} type="checkbox" label="Read-only (recommended)" />
    <p class="text-xs text-warning -mt-1 mb-2">
      Unchecking this allows INSERT/UPDATE/DELETE and DDL to run against
      this database from OneSQLx. Only disable it for databases you are
      comfortable modifying from here.
    </p>

    <div class="grid grid-cols-2 gap-4 mt-2">
      <.input
        field={@form[:statement_timeout_ms]}
        type="number"
        label="Query timeout (ms)"
        min="1000"
        max="600000"
        step="1000"
      />
      <.input
        field={@form[:max_row_limit]}
        type="number"
        label="Max rows (blank = no cap)"
        min="1"
        max="100000"
      />
    </div>
    <p class="text-xs text-base-content/60 -mt-1 mb-2">
      The timeout cancels queries server-side. The row cap bounds every
      result from this source — editor, exports, and schedules alike.
    </p>
    """
  end
end

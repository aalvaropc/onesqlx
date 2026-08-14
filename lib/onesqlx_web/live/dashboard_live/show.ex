defmodule OnesqlxWeb.DashboardLive.Show do
  @moduledoc """
  LiveView for viewing and editing a dashboard, with async per-card query execution.

  Markup lives in `OnesqlxWeb.DashboardLive.ShowComponents`; the card
  body is shared with the public/embed views via
  `OnesqlxWeb.DashboardLive.CardHelpers.card_content/1`.
  """

  use OnesqlxWeb, :live_view

  import OnesqlxWeb.DashboardLive.ShowComponents

  @query_timeout_ms 60_000
  @timeout_message "Query timed out after 60 seconds. The database may still be processing the query."

  alias Onesqlx.Dashboards
  alias Onesqlx.Dashboards.DashboardCard
  alias Onesqlx.Querying.Executor
  alias Onesqlx.Querying.Params
  alias Onesqlx.SavedQueries

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.breadcrumb items={[{"Dashboards", ~p"/dashboards"}, {@dashboard.title, nil}]} />
      <.toolbar
        dashboard={@dashboard}
        dashboard_param_names={@dashboard_param_names}
        dashboard_params={@dashboard_params}
        auto_refresh_interval={@auto_refresh_interval}
        editing?={@editing?}
      />
      <.filters_bar active_filters={@active_filters} />
      <.card_grid dashboard={@dashboard} card_results={@card_results} editing?={@editing?} />

      <div :if={@dashboard.cards == []} class="text-center py-12">
        <.icon name="hero-squares-plus" class="size-12 text-base-content/20 mx-auto mb-4" />
        <p class="text-base-content/60 mb-2">No cards yet</p>
        <p class="text-sm text-base-content/40">
          Click "Edit" then "Add Card" to add your first visualization.
        </p>
      </div>

      <div :if={@editing?} class="mt-6">
        <button phx-click="open_add_card_modal" class="btn btn-primary">
          <.icon name="hero-plus" class="size-4" /> Add Card
        </button>
      </div>

      <.add_card_modal
        show?={@show_add_card_modal?}
        form={@add_card_form}
        saved_queries={@saved_queries}
      />
      <.share_modal show?={@show_share_modal?} dashboard={@dashboard} />
      <.variables_modal show?={@show_variables_modal?} variables={@dashboard.variables} />
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope
    dashboard = Dashboards.get_dashboard_with_cards!(scope, id)

    if connected?(socket), do: Dashboards.subscribe(dashboard.id)

    card_results =
      Map.new(dashboard.cards, fn card ->
        {card.id, initial_card_result(card)}
      end)

    socket =
      socket
      |> assign(
        dashboard: dashboard,
        card_results: card_results,
        card_timeouts: %{},
        editing?: false,
        show_add_card_modal?: false,
        add_card_form: nil,
        saved_queries: [],
        auto_refresh_interval: 0,
        auto_refresh_ref: nil,
        show_share_modal?: false,
        show_variables_modal?: false,
        dashboard_param_names: dashboard_param_names(dashboard),
        dashboard_params: Dashboards.variable_defaults(dashboard),
        active_filters: %{},
        skip_cache?: false
      )
      |> start_card_async_tasks(dashboard.cards)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_share", _params, socket) do
    {:noreply, assign(socket, show_share_modal?: !socket.assigns.show_share_modal?)}
  end

  def handle_event("duplicate_dashboard", _params, socket) do
    scope = socket.assigns.current_scope

    case Dashboards.duplicate_dashboard(scope, socket.assigns.dashboard) do
      {:ok, new_dashboard} ->
        {:noreply,
         socket
         |> put_flash(:info, "Dashboard duplicated.")
         |> push_navigate(to: ~p"/dashboards/#{new_dashboard.id}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to duplicate dashboard.")}
    end
  end

  def handle_event("generate_share", _params, socket) do
    scope = socket.assigns.current_scope
    {:ok, updated} = Dashboards.generate_public_token(scope, socket.assigns.dashboard)
    {:noreply, assign(socket, dashboard: updated)}
  end

  def handle_event("revoke_share", _params, socket) do
    scope = socket.assigns.current_scope
    {:ok, updated} = Dashboards.revoke_public_token(scope, socket.assigns.dashboard)
    {:noreply, assign(socket, dashboard: updated)}
  end

  def handle_event("toggle_edit", _params, socket) do
    {:noreply, assign(socket, editing?: !socket.assigns.editing?)}
  end

  def handle_event("open_variables_modal", _params, socket) do
    {:noreply, assign(socket, show_variables_modal?: true)}
  end

  def handle_event("close_variables_modal", _params, socket) do
    {:noreply, assign(socket, show_variables_modal?: false)}
  end

  def handle_event("add_variable", %{"variable" => attrs}, socket) do
    scope = socket.assigns.current_scope
    dashboard = socket.assigns.dashboard
    variables = dashboard.variables ++ [attrs]

    case Dashboards.update_variables(scope, dashboard, variables) do
      {:ok, updated} ->
        {:noreply, after_variables_change(socket, updated)}

      {:error, changeset} ->
        message = variables_error(changeset)
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_event("remove_variable", %{"name" => name}, socket) do
    scope = socket.assigns.current_scope
    dashboard = socket.assigns.dashboard
    variables = Enum.reject(dashboard.variables, &(&1["name"] == name))

    case Dashboards.update_variables(scope, dashboard, variables) do
      {:ok, updated} ->
        {:noreply, after_variables_change(socket, updated)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not remove variable.")}
    end
  end

  def handle_event("refresh", _params, socket) do
    scope = socket.assigns.current_scope
    dashboard = Dashboards.get_dashboard_with_cards!(scope, socket.assigns.dashboard.id)

    cancel_all_card_timeouts(socket.assigns.card_timeouts)

    card_results =
      Map.new(dashboard.cards, fn card ->
        {card.id, initial_card_result(card)}
      end)

    socket =
      socket
      |> assign(
        dashboard: dashboard,
        card_results: card_results,
        card_timeouts: %{},
        skip_cache?: true
      )
      |> start_card_async_tasks(dashboard.cards)
      |> assign(skip_cache?: false)

    {:noreply, socket}
  end

  def handle_event("set_dashboard_param", %{"name" => name, "value" => value}, socket) do
    params = Map.put(socket.assigns.dashboard_params, name, value)
    {:noreply, assign(socket, dashboard_params: params)}
  end

  def handle_event("apply_dashboard_params", _params, socket) do
    scope = socket.assigns.current_scope
    dashboard = Dashboards.get_dashboard_with_cards!(scope, socket.assigns.dashboard.id)

    cancel_all_card_timeouts(socket.assigns.card_timeouts)

    card_results =
      Map.new(dashboard.cards, fn card ->
        {card.id, initial_card_result(card)}
      end)

    socket =
      socket
      |> assign(dashboard: dashboard, card_results: card_results, card_timeouts: %{})
      |> start_card_async_tasks(dashboard.cards)

    {:noreply, socket}
  end

  def handle_event("set_auto_refresh", %{"interval" => interval_str}, socket) do
    interval = String.to_integer(interval_str)

    if socket.assigns.auto_refresh_ref do
      Process.cancel_timer(socket.assigns.auto_refresh_ref)
    end

    ref =
      if interval > 0 do
        Process.send_after(self(), :auto_refresh, interval)
      end

    {:noreply, assign(socket, auto_refresh_interval: interval, auto_refresh_ref: ref)}
  end

  def handle_event("open_add_card_modal", _params, socket) do
    scope = socket.assigns.current_scope
    saved_queries = SavedQueries.list_saved_queries(scope)
    changeset = Dashboards.change_card(%DashboardCard{})

    socket =
      assign(socket,
        saved_queries: saved_queries,
        show_add_card_modal?: true,
        add_card_form: to_form(changeset, as: "card")
      )

    {:noreply, socket}
  end

  def handle_event("close_add_card_modal", _params, socket) do
    {:noreply, assign(socket, show_add_card_modal?: false, add_card_form: nil)}
  end

  def handle_event("validate_card", %{"card" => params}, socket) do
    changeset =
      %DashboardCard{}
      |> Dashboards.change_card(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, add_card_form: to_form(changeset, as: "card"))}
  end

  def handle_event("add_card", %{"card" => params}, socket) do
    scope = socket.assigns.current_scope
    dashboard = socket.assigns.dashboard

    case Dashboards.add_card(scope, dashboard, params) do
      {:ok, _card} ->
        dashboard = Dashboards.get_dashboard_with_cards!(scope, dashboard.id)
        new_card = List.last(dashboard.cards)

        card_results =
          socket.assigns.card_results
          |> Map.put(new_card.id, initial_card_result(new_card))

        socket =
          socket
          |> assign(
            dashboard: dashboard,
            card_results: card_results,
            show_add_card_modal?: false,
            add_card_form: nil
          )
          |> maybe_start_card_async(new_card)

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, add_card_form: to_form(changeset, as: "card"))}
    end
  end

  def handle_event("remove_card", %{"id" => card_id}, socket) do
    scope = socket.assigns.current_scope

    case Enum.find(socket.assigns.dashboard.cards, &(&1.id == card_id)) do
      nil ->
        {:noreply, socket}

      card ->
        {:ok, _} = Dashboards.remove_card(scope, card)
        dashboard = Dashboards.get_dashboard_with_cards!(scope, socket.assigns.dashboard.id)
        {:noreply, assign(socket, dashboard: dashboard)}
    end
  end

  def handle_event("move_card_up", %{"id" => card_id}, socket) do
    scope = socket.assigns.current_scope

    case Enum.find(socket.assigns.dashboard.cards, &(&1.id == card_id)) do
      nil ->
        {:noreply, socket}

      card ->
        {:ok, _} = Dashboards.move_card_up(scope, card)
        dashboard = Dashboards.get_dashboard_with_cards!(scope, socket.assigns.dashboard.id)
        {:noreply, assign(socket, dashboard: dashboard)}
    end
  end

  def handle_event("move_card_down", %{"id" => card_id}, socket) do
    scope = socket.assigns.current_scope

    case Enum.find(socket.assigns.dashboard.cards, &(&1.id == card_id)) do
      nil ->
        {:noreply, socket}

      card ->
        {:ok, _} = Dashboards.move_card_down(scope, card)
        dashboard = Dashboards.get_dashboard_with_cards!(scope, socket.assigns.dashboard.id)
        {:noreply, assign(socket, dashboard: dashboard)}
    end
  end

  def handle_event("reorder_cards", %{"ids" => card_ids}, socket) do
    scope = socket.assigns.current_scope
    dashboard = socket.assigns.dashboard

    Dashboards.reorder_cards(scope, dashboard, card_ids)
    dashboard = Dashboards.get_dashboard_with_cards!(scope, dashboard.id)
    {:noreply, assign(socket, dashboard: dashboard)}
  end

  def handle_event("set_card_span", %{"id" => card_id, "span" => span_str}, socket) do
    scope = socket.assigns.current_scope
    span = String.to_integer(span_str)

    case Enum.find(socket.assigns.dashboard.cards, &(&1.id == card_id)) do
      nil ->
        {:noreply, socket}

      card ->
        config = Map.put(card.config || %{}, "span", span)
        {:ok, _} = Dashboards.update_card(scope, card, %{config: config})
        dashboard = Dashboards.get_dashboard_with_cards!(scope, socket.assigns.dashboard.id)
        {:noreply, assign(socket, dashboard: dashboard)}
    end
  end

  def handle_event("chart_filter", %{"field" => field, "value" => value}, socket) do
    scope = socket.assigns.current_scope
    dashboard = Dashboards.get_dashboard_with_cards!(scope, socket.assigns.dashboard.id)

    params = Map.put(socket.assigns.dashboard_params, field, value)
    filters = Map.put(socket.assigns.active_filters, field, value)

    cancel_all_card_timeouts(socket.assigns.card_timeouts)

    card_results =
      Map.new(dashboard.cards, fn card ->
        {card.id, initial_card_result(card)}
      end)

    socket =
      socket
      |> assign(
        dashboard: dashboard,
        dashboard_params: params,
        active_filters: filters,
        card_results: card_results,
        card_timeouts: %{},
        skip_cache?: true
      )
      |> start_card_async_tasks(dashboard.cards)
      |> assign(skip_cache?: false)

    {:noreply, socket}
  end

  def handle_event("clear_filters", _params, socket) do
    scope = socket.assigns.current_scope
    dashboard = Dashboards.get_dashboard_with_cards!(scope, socket.assigns.dashboard.id)

    # Remove filter params from dashboard_params
    filter_keys = Map.keys(socket.assigns.active_filters)
    params = Map.drop(socket.assigns.dashboard_params, filter_keys)

    cancel_all_card_timeouts(socket.assigns.card_timeouts)

    card_results =
      Map.new(dashboard.cards, fn card ->
        {card.id, initial_card_result(card)}
      end)

    socket =
      socket
      |> assign(
        dashboard: dashboard,
        dashboard_params: params,
        active_filters: %{},
        card_results: card_results,
        card_timeouts: %{},
        skip_cache?: true
      )
      |> start_card_async_tasks(dashboard.cards)
      |> assign(skip_cache?: false)

    {:noreply, socket}
  end

  @impl true
  def handle_async({:execute_card, id}, {:ok, {:ok, result}}, socket) do
    if Map.get(socket.assigns.card_results, id) == :loading do
      cancel_card_timeout(socket, id)

      socket =
        socket
        |> update(:card_results, &Map.put(&1, id, {:ok, result}))
        |> update(:card_timeouts, &Map.delete(&1, id))

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_async({:execute_card, id}, {:ok, {:error, _type, msg}}, socket) do
    if Map.get(socket.assigns.card_results, id) == :loading do
      cancel_card_timeout(socket, id)

      socket =
        socket
        |> update(:card_results, &Map.put(&1, id, {:error, msg}))
        |> update(:card_timeouts, &Map.delete(&1, id))

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_async({:execute_card, id}, {:exit, reason}, socket) do
    if Map.get(socket.assigns.card_results, id) == :loading do
      cancel_card_timeout(socket, id)
      msg = "Query process crashed: #{inspect(reason)}"

      socket =
        socket
        |> update(:card_results, &Map.put(&1, id, {:error, msg}))
        |> update(:card_timeouts, &Map.delete(&1, id))

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Another user (or an API client) changed this dashboard — reload it
  # and re-run the cards. The mutating process is excluded from the
  # broadcast, so this never double-runs for the editor.
  @impl true
  def handle_info({:dashboard_updated, _id}, socket) do
    scope = socket.assigns.current_scope
    dashboard = Dashboards.get_dashboard_with_cards!(scope, socket.assigns.dashboard.id)

    cancel_all_card_timeouts(socket.assigns.card_timeouts)

    card_results =
      Map.new(dashboard.cards, fn card ->
        {card.id, initial_card_result(card)}
      end)

    socket =
      socket
      |> assign(
        dashboard: dashboard,
        dashboard_param_names: dashboard_param_names(dashboard),
        card_results: card_results,
        card_timeouts: %{}
      )
      |> start_card_async_tasks(dashboard.cards)

    {:noreply, socket}
  end

  def handle_info({:card_timeout, card_id}, socket) do
    if Map.get(socket.assigns.card_results, card_id) == :loading do
      socket =
        socket
        |> update(:card_results, &Map.put(&1, card_id, {:error, @timeout_message}))
        |> update(:card_timeouts, &Map.delete(&1, card_id))

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:auto_refresh, socket) do
    interval = socket.assigns.auto_refresh_interval

    if interval > 0 do
      scope = socket.assigns.current_scope
      dashboard = Dashboards.get_dashboard_with_cards!(scope, socket.assigns.dashboard.id)

      cancel_all_card_timeouts(socket.assigns.card_timeouts)

      card_results =
        Map.new(dashboard.cards, fn card ->
          {card.id, initial_card_result(card)}
        end)

      ref = Process.send_after(self(), :auto_refresh, interval)

      socket =
        socket
        |> assign(
          dashboard: dashboard,
          card_results: card_results,
          card_timeouts: %{},
          auto_refresh_ref: ref
        )
        |> start_card_async_tasks(dashboard.cards)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp extract_dashboard_params(cards) do
    cards
    |> Enum.flat_map(fn
      %{saved_query: %{sql: sql}} when is_binary(sql) -> Params.extract(sql)
      _ -> []
    end)
    |> Enum.uniq()
  end

  # Filter bar shows defined variables first, then any :params detected
  # in card SQL that no variable covers yet.
  defp dashboard_param_names(dashboard) do
    defined = Enum.map(dashboard.variables || [], & &1["name"])
    Enum.uniq(defined ++ extract_dashboard_params(dashboard.cards))
  end

  defp after_variables_change(socket, updated_dashboard) do
    defaults = Dashboards.variable_defaults(updated_dashboard)

    # New defaults fill in only where the user hasn't set a value
    params = Map.merge(defaults, socket.assigns.dashboard_params)

    socket
    |> assign(
      dashboard: updated_dashboard,
      dashboard_param_names: dashboard_param_names(updated_dashboard),
      dashboard_params: params
    )
  end

  defp variables_error(changeset) do
    case changeset.errors[:variables] do
      {message, _} -> message
      _ -> "Could not save variable."
    end
  end

  defp initial_card_result(%{type: "markdown"}), do: :not_applicable
  defp initial_card_result(%{saved_query: %{data_source: %{}} = _sq}), do: :loading
  defp initial_card_result(_card), do: {:error, "No query assigned"}

  defp start_card_async_tasks(socket, cards) do
    Enum.reduce(cards, socket, &maybe_start_card_async(&2, &1))
  end

  @default_cache_ttl 300_000

  defp maybe_start_card_async(socket, card) do
    case card do
      %{saved_query: %{data_source: data_source, sql: sql}} when not is_nil(data_source) ->
        card_params = get_in(card.config, ["params"]) || %{}
        dashboard_params = socket.assigns.dashboard_params || %{}
        merged_params = Map.merge(card_params, dashboard_params)
        skip_cache? = socket.assigns[:skip_cache?] || false
        ref = Process.send_after(self(), {:card_timeout, card.id}, @query_timeout_ms)

        socket
        |> update(:card_timeouts, &Map.put(&1, card.id, ref))
        |> start_async({:execute_card, card.id}, fn ->
          Executor.execute(data_source, sql,
            params: merged_params,
            cache_ttl: @default_cache_ttl,
            skip_cache: skip_cache?
          )
        end)

      _ ->
        socket
    end
  end

  defp cancel_card_timeout(socket, card_id) do
    case Map.get(socket.assigns.card_timeouts, card_id) do
      nil -> :ok
      ref -> Process.cancel_timer(ref)
    end
  end

  defp cancel_all_card_timeouts(card_timeouts) do
    Enum.each(card_timeouts, fn {_id, ref} -> Process.cancel_timer(ref) end)
  end
end

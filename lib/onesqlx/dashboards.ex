defmodule Onesqlx.Dashboards do
  @moduledoc """
  The Dashboards context.

  Manages dashboards and panels with visualizations. Dashboards combine
  multiple saved queries into a unified view with charts and tables.
  """

  import Ecto.Query

  alias Onesqlx.Accounts.Scope
  alias Onesqlx.Audit
  alias Onesqlx.Dashboards.Dashboard
  alias Onesqlx.Dashboards.DashboardCard
  alias Onesqlx.Repo

  @spec list_dashboards(Scope.t(), keyword()) :: [Dashboard.t()]
  @doc """
  Lists all dashboards for the workspace, ordered by updated_at desc.
  """
  def list_dashboards(%Scope{} = scope, opts \\ []) do
    Dashboard
    |> where(workspace_id: ^scope.workspace.id)
    |> order_by(desc: :updated_at)
    |> maybe_apply_limit(opts[:limit])
    |> maybe_apply_offset(opts[:offset])
    |> Repo.all()
  end

  @spec count_dashboards(Scope.t()) :: non_neg_integer()
  @doc """
  Counts dashboards for the workspace.
  """
  def count_dashboards(%Scope{} = scope) do
    Dashboard
    |> where(workspace_id: ^scope.workspace.id)
    |> Repo.aggregate(:count)
  end

  @spec get_dashboard!(Scope.t(), String.t()) :: Dashboard.t()
  @doc """
  Gets a single dashboard scoped to the workspace.

  Raises `Ecto.NoResultsError` if not found.
  """
  def get_dashboard!(%Scope{} = scope, id) do
    Dashboard
    |> where(workspace_id: ^scope.workspace.id, id: ^id)
    |> Repo.one!()
  end

  @spec get_dashboard_with_cards!(Scope.t(), String.t()) :: Dashboard.t()
  @doc """
  Gets a single dashboard with its cards (and each card's saved_query + data_source) preloaded.

  Raises `Ecto.NoResultsError` if not found.
  """
  def get_dashboard_with_cards!(%Scope{} = scope, id) do
    Dashboard
    |> where(workspace_id: ^scope.workspace.id, id: ^id)
    |> preload(cards: ^ordered_cards_query())
    |> Repo.one!()
  end

  @spec create_dashboard(Scope.t(), map()) :: {:ok, Dashboard.t()} | {:error, Ecto.Changeset.t()}
  @doc """
  Creates a dashboard for the workspace in the given scope.
  """
  def create_dashboard(%Scope{} = scope, attrs) do
    result =
      %Dashboard{workspace_id: scope.workspace.id, user_id: scope.user.id}
      |> Dashboard.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, d} ->
        Audit.safe_record_event(scope, "dashboard.created", %{
          resource_type: "dashboard",
          resource_id: d.id
        })

      _ ->
        :ok
    end

    result
  end

  @spec update_dashboard(Scope.t(), Dashboard.t(), map()) ::
          {:ok, Dashboard.t()} | {:error, Ecto.Changeset.t()}
  @doc """
  Updates a dashboard.
  """
  def update_dashboard(%Scope{} = scope, %Dashboard{} = dashboard, attrs) do
    verify_ownership!(scope, dashboard)

    dashboard
    |> Dashboard.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_dashboard(Scope.t(), Dashboard.t()) ::
          {:ok, Dashboard.t()} | {:error, Ecto.Changeset.t()}
  @doc """
  Deletes a dashboard. Cascades to its cards.
  """
  def delete_dashboard(%Scope{} = scope, %Dashboard{} = dashboard) do
    verify_ownership!(scope, dashboard)
    result = Repo.delete(dashboard)

    case result do
      {:ok, d} ->
        Audit.safe_record_event(scope, "dashboard.deleted", %{
          resource_type: "dashboard",
          resource_id: d.id
        })

      _ ->
        :ok
    end

    result
  end

  @doc """
  Duplicates a dashboard with all its cards.

  Creates a new dashboard with " (copy)" appended to the title,
  and clones all cards preserving saved_query_id, type, config, and position.
  """
  def duplicate_dashboard(%Scope{} = scope, %Dashboard{} = dashboard) do
    dashboard = get_dashboard_with_cards!(scope, dashboard.id)

    Repo.transaction(fn ->
      {:ok, new_dashboard} =
        create_dashboard(scope, %{
          title: dashboard.title <> " (copy)",
          description: dashboard.description
        })

      Enum.each(dashboard.cards, fn card ->
        %DashboardCard{dashboard_id: new_dashboard.id}
        |> DashboardCard.changeset(%{
          type: card.type,
          title: card.title,
          position: card.position,
          config: card.config,
          saved_query_id: card.saved_query_id
        })
        |> Repo.insert!()
      end)

      new_dashboard
    end)
  end

  @spec update_variables(Scope.t(), Dashboard.t(), [map()]) ::
          {:ok, Dashboard.t()} | {:error, Ecto.Changeset.t()}
  @doc """
  Replaces the dashboard-level variable definitions.

  Variables map to the `:name` named parameters of the cards' saved
  queries and provide a type, label, and default value for the
  dashboard's filter bar (including public/embed views).
  """
  def update_variables(%Scope{} = scope, %Dashboard{} = dashboard, variables) do
    verify_ownership!(scope, dashboard)

    dashboard
    |> Dashboard.variables_changeset(variables)
    |> Repo.update()
  end

  @doc """
  The default parameter values from a dashboard's variable definitions:
  `%{"name" => default}` for every variable with a non-empty default.
  """
  def variable_defaults(%Dashboard{variables: variables}) do
    for %{"name" => name, "default" => default} <- variables || [],
        default not in [nil, ""],
        into: %{},
        do: {name, default}
  end

  @spec generate_public_token(Scope.t(), Dashboard.t()) ::
          {:ok, Dashboard.t()} | {:error, Ecto.Changeset.t()}
  @doc """
  Generates a public sharing token for a dashboard.
  """
  def generate_public_token(%Scope{} = scope, %Dashboard{} = dashboard) do
    verify_ownership!(scope, dashboard)

    dashboard
    |> Ecto.Changeset.change(public_token: Ecto.UUID.generate())
    |> Repo.update()
  end

  @doc """
  Revokes a dashboard's public sharing token.
  """
  @spec revoke_public_token(Scope.t(), Dashboard.t()) ::
          {:ok, Dashboard.t()} | {:error, Ecto.Changeset.t()}
  def revoke_public_token(%Scope{} = scope, %Dashboard{} = dashboard) do
    verify_ownership!(scope, dashboard)

    dashboard
    |> Ecto.Changeset.change(public_token: nil)
    |> Repo.update()
  end

  @doc """
  Gets a dashboard by public token. No scope required.
  Raises `Ecto.NoResultsError` if not found or token is nil.
  """
  @spec get_public_dashboard!(String.t()) :: Dashboard.t()
  def get_public_dashboard!(token) when is_binary(token) do
    Dashboard
    |> where(public_token: ^token)
    |> preload(cards: ^ordered_cards_query())
    |> Repo.one!()
  end

  @spec change_dashboard(Dashboard.t(), map()) :: Ecto.Changeset.t()
  @doc """
  Returns a changeset for tracking dashboard changes.
  """
  def change_dashboard(%Dashboard{} = dashboard, attrs \\ %{}) do
    Dashboard.changeset(dashboard, attrs)
  end

  @spec add_card(Scope.t(), Dashboard.t(), map()) ::
          {:ok, DashboardCard.t()} | {:error, Ecto.Changeset.t()}
  @doc """
  Adds a card to a dashboard. Position is set to max(position) + 1.
  """
  def add_card(%Scope{} = scope, %Dashboard{} = dashboard, attrs) do
    verify_ownership!(scope, dashboard)

    Repo.transaction(fn ->
      # Lock dashboard row to serialize concurrent card inserts
      from(d in Dashboard, where: d.id == ^dashboard.id, lock: "FOR UPDATE")
      |> Repo.one!()

      max_pos_query =
        from(c in DashboardCard, where: c.dashboard_id == ^dashboard.id, select: max(c.position))

      next_position = (Repo.one(max_pos_query) || -1) + 1

      case %DashboardCard{dashboard_id: dashboard.id, position: next_position}
           |> DashboardCard.changeset(attrs)
           |> Repo.insert() do
        {:ok, card} -> card
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @spec remove_card(Scope.t(), DashboardCard.t()) ::
          {:ok, DashboardCard.t()} | {:error, Ecto.Changeset.t()}
  @doc """
  Removes a card from a dashboard.
  """
  def remove_card(%Scope{} = scope, %DashboardCard{} = card) do
    verify_card_ownership!(scope, card)
    Repo.delete(card)
  end

  @spec update_card(Scope.t(), DashboardCard.t(), map()) ::
          {:ok, DashboardCard.t()} | {:error, Ecto.Changeset.t()}
  @doc """
  Updates a card's type, title, or config.
  """
  def update_card(%Scope{} = scope, %DashboardCard{} = card, attrs) do
    verify_card_ownership!(scope, card)

    card
    |> DashboardCard.changeset(attrs)
    |> Repo.update()
  end

  @spec move_card_up(Scope.t(), DashboardCard.t()) :: {:ok, DashboardCard.t()}
  @doc """
  Moves a card up by swapping positions with the nearest preceding card.
  No-op if already first.
  """
  def move_card_up(%Scope{} = scope, %DashboardCard{} = card) do
    verify_card_ownership!(scope, card)

    neighbor_query =
      from(c in DashboardCard,
        where: c.dashboard_id == ^card.dashboard_id and c.position < ^card.position,
        order_by: [desc: c.position],
        limit: 1
      )

    case Repo.one(neighbor_query) do
      nil ->
        {:ok, card}

      neighbor ->
        Repo.transaction(fn ->
          Repo.update_all(
            from(c in DashboardCard, where: c.id == ^card.id),
            set: [position: neighbor.position]
          )

          Repo.update_all(
            from(c in DashboardCard, where: c.id == ^neighbor.id),
            set: [position: card.position]
          )

          Repo.get!(DashboardCard, card.id)
        end)
    end
  end

  @spec move_card_down(Scope.t(), DashboardCard.t()) :: {:ok, DashboardCard.t()}
  @doc """
  Moves a card down by swapping positions with the nearest following card.
  No-op if already last.
  """
  def move_card_down(%Scope{} = scope, %DashboardCard{} = card) do
    verify_card_ownership!(scope, card)

    neighbor_query =
      from(c in DashboardCard,
        where: c.dashboard_id == ^card.dashboard_id and c.position > ^card.position,
        order_by: [asc: c.position],
        limit: 1
      )

    case Repo.one(neighbor_query) do
      nil ->
        {:ok, card}

      neighbor ->
        Repo.transaction(fn ->
          Repo.update_all(
            from(c in DashboardCard, where: c.id == ^card.id),
            set: [position: neighbor.position]
          )

          Repo.update_all(
            from(c in DashboardCard, where: c.id == ^neighbor.id),
            set: [position: card.position]
          )

          Repo.get!(DashboardCard, card.id)
        end)
    end
  end

  @doc """
  Reorders cards by setting positions from a list of card IDs in the desired order.
  """
  def reorder_cards(%Scope{} = scope, %Dashboard{} = dashboard, card_ids)
      when is_list(card_ids) do
    verify_ownership!(scope, dashboard)

    Repo.transaction(fn ->
      card_ids
      |> Enum.with_index()
      |> Enum.each(fn {card_id, index} ->
        from(c in DashboardCard, where: c.id == ^card_id and c.dashboard_id == ^dashboard.id)
        |> Repo.update_all(set: [position: index])
      end)
    end)
  end

  @spec change_card(DashboardCard.t(), map()) :: Ecto.Changeset.t()
  @doc """
  Returns a changeset for tracking card changes.
  """
  def change_card(%DashboardCard{} = card, attrs \\ %{}) do
    DashboardCard.changeset(card, attrs)
  end

  defp verify_ownership!(%Scope{} = scope, %Dashboard{} = resource) do
    if resource.workspace_id != scope.workspace.id,
      do: raise(Ecto.NoResultsError, queryable: Dashboard)

    Onesqlx.Authorization.authorize_manage!(scope, resource)
  end

  defp verify_card_ownership!(%Scope{} = scope, %DashboardCard{} = card) do
    dashboard = Repo.get!(Dashboard, card.dashboard_id)

    if dashboard.workspace_id != scope.workspace.id,
      do: raise(Ecto.NoResultsError, queryable: DashboardCard)

    card
  end

  defp ordered_cards_query do
    from(c in DashboardCard,
      order_by: [asc: c.position],
      preload: [saved_query: :data_source]
    )
  end

  defp maybe_apply_limit(query, nil), do: query
  defp maybe_apply_limit(query, limit), do: limit(query, ^limit)

  defp maybe_apply_offset(query, nil), do: query
  defp maybe_apply_offset(query, offset), do: offset(query, ^offset)
end

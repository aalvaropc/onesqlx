defmodule Onesqlx.Dashboards do
  @moduledoc """
  The Dashboards context.

  Manages dashboards and panels with visualizations. Dashboards combine
  multiple saved queries into a unified view with charts and tables.
  """

  import Ecto.Query

  alias Onesqlx.Accounts.Scope
  alias Onesqlx.Dashboards.Dashboard
  alias Onesqlx.Dashboards.DashboardCard
  alias Onesqlx.Repo

  @doc """
  Lists all dashboards for the workspace, ordered by updated_at desc.
  """
  def list_dashboards(%Scope{} = scope) do
    Dashboard
    |> where(workspace_id: ^scope.workspace.id)
    |> order_by(desc: :updated_at)
    |> Repo.all()
  end

  @doc """
  Gets a single dashboard scoped to the workspace.

  Raises `Ecto.NoResultsError` if not found.
  """
  def get_dashboard!(%Scope{} = scope, id) do
    Dashboard
    |> where(workspace_id: ^scope.workspace.id, id: ^id)
    |> Repo.one!()
  end

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

  @doc """
  Creates a dashboard for the workspace in the given scope.
  """
  def create_dashboard(%Scope{} = scope, attrs) do
    %Dashboard{workspace_id: scope.workspace.id, user_id: scope.user.id}
    |> Dashboard.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a dashboard.
  """
  def update_dashboard(%Scope{} = _scope, %Dashboard{} = dashboard, attrs) do
    dashboard
    |> Dashboard.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a dashboard. Cascades to its cards.
  """
  def delete_dashboard(%Scope{} = _scope, %Dashboard{} = dashboard) do
    Repo.delete(dashboard)
  end

  @doc """
  Returns a changeset for tracking dashboard changes.
  """
  def change_dashboard(%Dashboard{} = dashboard, attrs \\ %{}) do
    Dashboard.changeset(dashboard, attrs)
  end

  @doc """
  Adds a card to a dashboard. Position is set to max(position) + 1.
  """
  def add_card(%Scope{} = _scope, %Dashboard{} = dashboard, attrs) do
    max_pos_query =
      from(c in DashboardCard, where: c.dashboard_id == ^dashboard.id, select: max(c.position))

    next_position = (Repo.one(max_pos_query) || -1) + 1

    %DashboardCard{dashboard_id: dashboard.id, position: next_position}
    |> DashboardCard.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Removes a card from a dashboard.
  """
  def remove_card(%Scope{} = _scope, %DashboardCard{} = card) do
    Repo.delete(card)
  end

  @doc """
  Updates a card's type, title, or config.
  """
  def update_card(%Scope{} = _scope, %DashboardCard{} = card, attrs) do
    card
    |> DashboardCard.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Moves a card up by swapping positions with the nearest preceding card.
  No-op if already first.
  """
  def move_card_up(%Scope{} = _scope, %DashboardCard{} = card) do
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

  @doc """
  Moves a card down by swapping positions with the nearest following card.
  No-op if already last.
  """
  def move_card_down(%Scope{} = _scope, %DashboardCard{} = card) do
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
  Returns a changeset for tracking card changes.
  """
  def change_card(%DashboardCard{} = card, attrs \\ %{}) do
    DashboardCard.changeset(card, attrs)
  end

  defp ordered_cards_query do
    from(c in DashboardCard,
      order_by: [asc: c.position],
      preload: [saved_query: :data_source]
    )
  end
end

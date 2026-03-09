defmodule OnesqlxWeb.DashboardLive do
  @moduledoc """
  Main dashboard for authenticated users.
  """

  use OnesqlxWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Dashboard
        <:subtitle>
          Welcome to OneSQLx, {@current_scope.user.email}
        </:subtitle>
      </.header>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end

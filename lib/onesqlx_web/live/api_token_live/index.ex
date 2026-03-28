defmodule OnesqlxWeb.ApiTokenLive.Index do
  @moduledoc """
  LiveView for managing API tokens.
  """

  use OnesqlxWeb, :live_view

  alias Onesqlx.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        API Tokens
        <:subtitle>Manage tokens for programmatic access to the API.</:subtitle>
        <:actions>
          <.button variant="primary" phx-click="open_create_modal">Create Token</.button>
        </:actions>
      </.header>

      <div id="tokens" phx-update="stream" class="space-y-3 mt-6">
        <div
          :for={{dom_id, token} <- @streams.tokens}
          id={dom_id}
          class="card border border-base-300 p-4"
        >
          <div class="flex items-center justify-between">
            <div>
              <h3 class="font-semibold">{token.name}</h3>
              <div class="flex items-center gap-4 mt-1 text-xs text-base-content/50">
                <span>Created {Calendar.strftime(token.inserted_at, "%Y-%m-%d")}</span>
                <span :if={token.last_used_at}>
                  Last used {Calendar.strftime(token.last_used_at, "%Y-%m-%d %H:%M")}
                </span>
                <span :if={!token.last_used_at}>Never used</span>
              </div>
            </div>
            <button
              phx-click="revoke"
              phx-value-id={token.id}
              data-confirm="Revoke this token? This cannot be undone."
              class="btn btn-sm btn-ghost text-error"
            >
              Revoke
            </button>
          </div>
        </div>
      </div>

      <div :if={!@has_tokens?} class="text-center py-12">
        <p class="text-base-content/60">No API tokens yet. Create one to access the REST API.</p>
      </div>

      <%!-- Create token modal --%>
      <div :if={@show_create_modal?} class="fixed inset-0 z-50 flex items-center justify-center">
        <div class="fixed inset-0 bg-black/50" phx-click="close_create_modal"></div>
        <div class="relative bg-base-100 rounded-lg p-6 w-full max-w-md shadow-xl">
          <h3 class="text-lg font-semibold mb-4">Create API Token</h3>
          <form phx-submit="create_token">
            <div class="form-control mb-4">
              <label class="label"><span class="label-text">Token Name</span></label>
              <input
                type="text"
                name="name"
                required
                placeholder="e.g. CI Pipeline"
                class="input input-bordered w-full"
              />
            </div>
            <div class="flex justify-end gap-2">
              <button type="button" phx-click="close_create_modal" class="btn btn-sm">Cancel</button>
              <.button variant="primary" phx-disable-with="Creating...">Create</.button>
            </div>
          </form>
        </div>
      </div>

      <%!-- Show raw token modal (once only) --%>
      <div :if={@raw_token} class="fixed inset-0 z-50 flex items-center justify-center">
        <div class="fixed inset-0 bg-black/50"></div>
        <div class="relative bg-base-100 rounded-lg p-6 w-full max-w-lg shadow-xl">
          <h3 class="text-lg font-semibold mb-2">Token Created</h3>
          <p class="text-sm text-base-content/60 mb-4">
            Copy this token now. It will not be shown again.
          </p>
          <div class="bg-base-200 rounded p-3 font-mono text-sm break-all select-all">
            {@raw_token}
          </div>
          <div class="flex justify-end mt-4">
            <button phx-click="dismiss_raw_token" class="btn btn-sm btn-primary">Done</button>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    tokens = Accounts.list_api_tokens(scope)

    socket =
      socket
      |> assign(
        has_tokens?: tokens != [],
        show_create_modal?: false,
        raw_token: nil
      )
      |> stream(:tokens, tokens)

    {:ok, socket}
  end

  @impl true
  def handle_event("open_create_modal", _params, socket) do
    {:noreply, assign(socket, show_create_modal?: true)}
  end

  def handle_event("close_create_modal", _params, socket) do
    {:noreply, assign(socket, show_create_modal?: false)}
  end

  def handle_event("create_token", %{"name" => name}, socket) do
    scope = socket.assigns.current_scope

    case Accounts.create_api_token(scope, name) do
      {:ok, raw_token, token} ->
        socket =
          socket
          |> stream_insert(:tokens, token)
          |> assign(has_tokens?: true, show_create_modal?: false, raw_token: raw_token)

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply,
         put_flash(socket, :error, "Failed to create token. Name may already be taken.")}
    end
  end

  def handle_event("dismiss_raw_token", _params, socket) do
    {:noreply, assign(socket, raw_token: nil)}
  end

  def handle_event("revoke", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    {:ok, token} = Accounts.delete_api_token(scope, id)

    tokens_empty? = Accounts.list_api_tokens(scope) == []

    socket =
      socket
      |> stream_delete(:tokens, token)
      |> assign(has_tokens?: !tokens_empty?)

    {:noreply, socket}
  end
end

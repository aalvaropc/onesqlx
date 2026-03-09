defmodule OnesqlxWeb.DataSourceLive.New do
  use OnesqlxWeb, :live_view

  alias Onesqlx.DataSources
  alias Onesqlx.DataSources.DataSource

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-lg">
        <.header>
          New Data Source
          <:subtitle>
            Connect an external PostgreSQL database to your workspace.
          </:subtitle>
        </.header>

        <.form for={@form} id="data-source-form" phx-submit="save" phx-change="validate">
          <.input field={@form[:name]} type="text" label="Name" required />
          <.input field={@form[:host]} type="text" label="Host" required />
          <.input field={@form[:port]} type="number" label="Port" value="5432" required />
          <.input field={@form[:database_name]} type="text" label="Database Name" required />
          <.input field={@form[:username]} type="text" label="Username" required />
          <.input field={@form[:password]} type="password" label="Password" required />
          <.input field={@form[:ssl_enabled]} type="checkbox" label="Enable SSL" />

          <div class="flex items-center gap-4 mt-6">
            <.button
              type="button"
              phx-click="test_connection"
              disabled={@testing?}
            >
              {if @testing?, do: "Testing...", else: "Test Connection"}
            </.button>

            <.button variant="primary" phx-disable-with="Saving...">
              Save Data Source
            </.button>
          </div>

          <div :if={@test_result} class="mt-4">
            <p :if={@test_result == :ok} class="text-success">
              Connection successful! (latency: {@test_latency_ms}ms)
            </p>
            <p :if={@test_result == :error} class="text-error">
              {@test_error}
            </p>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    changeset = DataSources.change_data_source(%DataSource{})

    socket =
      socket
      |> assign(:testing?, false)
      |> assign(:test_result, nil)
      |> assign(:test_latency_ms, nil)
      |> assign(:test_error, nil)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("validate", %{"data_source" => params}, socket) do
    changeset =
      %DataSource{}
      |> DataSources.change_data_source(params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:test_result, nil)
     |> assign_form(changeset)}
  end

  def handle_event("test_connection", _params, socket) do
    params = socket.assigns.form.params

    socket =
      socket
      |> assign(:testing?, true)
      |> assign(:test_result, nil)
      |> start_async(:test_connection, fn ->
        DataSources.test_connection_from_attrs(params)
      end)

    {:noreply, socket}
  end

  def handle_event("save", %{"data_source" => params}, socket) do
    scope = socket.assigns.current_scope

    case DataSources.create_data_source(scope, params) do
      {:ok, _data_source} ->
        {:noreply,
         socket
         |> put_flash(:info, "Data source created successfully.")
         |> push_navigate(to: ~p"/data-sources")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  @impl true
  def handle_async(:test_connection, {:ok, {:ok, %{latency_ms: latency}}}, socket) do
    {:noreply,
     socket
     |> assign(:testing?, false)
     |> assign(:test_result, :ok)
     |> assign(:test_latency_ms, latency)}
  end

  def handle_async(:test_connection, {:ok, {:error, message}}, socket) do
    {:noreply,
     socket
     |> assign(:testing?, false)
     |> assign(:test_result, :error)
     |> assign(:test_error, message)}
  end

  def handle_async(:test_connection, {:exit, _reason}, socket) do
    {:noreply,
     socket
     |> assign(:testing?, false)
     |> assign(:test_result, :error)
     |> assign(:test_error, "Connection test failed unexpectedly.")}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: "data_source"))
  end
end

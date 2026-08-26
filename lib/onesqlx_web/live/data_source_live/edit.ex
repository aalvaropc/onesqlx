defmodule OnesqlxWeb.DataSourceLive.Edit do
  use OnesqlxWeb, :live_view

  import OnesqlxWeb.DataSourceLive.FormComponents

  alias Onesqlx.DataSources

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-lg">
        <.header>
          Edit Data Source
          <:subtitle>
            Connection settings and query limits for {@data_source.name}.
          </:subtitle>
        </.header>

        <.form for={@form} id="data-source-form" phx-submit="save" phx-change="validate">
          <.connection_fields form={@form} mode={:edit} />

          <div class="flex items-center gap-4 mt-6">
            <.button type="button" phx-click="test_connection" disabled={@testing?}>
              {if @testing?, do: "Testing...", else: "Test Connection"}
            </.button>

            <.button variant="primary" phx-disable-with="Saving...">
              Save Changes
            </.button>

            <.link navigate={~p"/data-sources"} class="link text-sm">Cancel</.link>
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
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope
    data_source = DataSources.get_data_source!(scope, id)
    changeset = DataSources.change_data_source(data_source)

    socket =
      socket
      |> assign(:data_source, data_source)
      |> assign(:testing?, false)
      |> assign(:test_result, nil)
      |> assign(:test_latency_ms, nil)
      |> assign(:test_error, nil)
      |> assign_form(changeset)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"data_source" => params}, socket) do
    changeset =
      socket.assigns.data_source
      |> DataSources.change_data_source(params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:test_result, nil)
     |> assign_form(changeset)}
  end

  def handle_event("test_connection", _params, socket) do
    params = test_attrs(socket)

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

    case DataSources.update_data_source(scope, socket.assigns.data_source, params) do
      {:ok, _data_source} ->
        {:noreply,
         socket
         |> put_flash(:info, "Data source updated.")
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

  # Test with the form values; a blank password means "keep the stored
  # one", so fall back to it for the connection test too.
  defp test_attrs(socket) do
    data_source = socket.assigns.data_source
    params = socket.assigns.form.params

    base = %{
      "host" => data_source.host,
      "port" => data_source.port,
      "database_name" => data_source.database_name,
      "username" => data_source.username,
      "ssl_enabled" => data_source.ssl_enabled
    }

    merged = Map.merge(base, Map.take(params, Map.keys(base)))

    case params["password"] do
      blank when blank in [nil, ""] ->
        Map.put(merged, "password", DataSources.decrypt_password(data_source))

      password ->
        Map.put(merged, "password", password)
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: "data_source"))
  end
end

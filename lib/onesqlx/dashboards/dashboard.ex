defmodule Onesqlx.Dashboards.Dashboard do
  @moduledoc """
  Schema for dashboards.

  Dashboards group saved queries into a unified view with charts and tables.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "dashboards" do
    field :title, :string
    field :description, :string
    field :public_token, :binary_id
    field :variables, {:array, :map}, default: []

    belongs_to :workspace, Onesqlx.Workspaces.Workspace
    belongs_to :user, Onesqlx.Accounts.User
    has_many :cards, Onesqlx.Dashboards.DashboardCard, preload_order: [asc: :position]

    timestamps(type: :utc_datetime)
  end

  @required_fields [:title]
  @optional_fields [:description, :user_id]

  def changeset(dashboard, attrs) do
    dashboard
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:title, min: 1, max: 255)
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:workspace_id, :title], error_key: :title)
  end

  @variable_types ~w(text number date)
  @variable_name_format ~r/^[a-zA-Z_][a-zA-Z0-9_]*$/

  @doc """
  Changeset for the dashboard-level variables definition.

  Each variable is a map with `"name"` (required, valid identifier),
  `"type"` (#{inspect(@variable_types)}, defaults to `"text"`), and
  optional `"label"` and `"default"`. Unknown keys are dropped.
  """
  def variables_changeset(dashboard, variables) when is_list(variables) do
    change(dashboard)
    |> put_change(:variables, Enum.map(variables, &normalize_variable/1))
    |> validate_change(:variables, fn :variables, vars ->
      cond do
        Enum.any?(vars, &(!valid_variable_name?(&1["name"]))) ->
          [variables: "variable names must be valid identifiers (letters, digits, _)"]

        Enum.any?(vars, &(&1["type"] not in @variable_types)) ->
          [variables: "variable type must be one of: #{Enum.join(@variable_types, ", ")}"]

        vars |> Enum.map(& &1["name"]) |> Enum.uniq() |> length() != length(vars) ->
          [variables: "variable names must be unique"]

        true ->
          []
      end
    end)
  end

  defp normalize_variable(var) do
    var = for {k, v} <- var, into: %{}, do: {to_string(k), v}

    %{
      "name" => var["name"],
      "type" => var["type"] || "text",
      "label" => var["label"],
      "default" => var["default"]
    }
  end

  defp valid_variable_name?(name) when is_binary(name),
    do: Regex.match?(@variable_name_format, name)

  defp valid_variable_name?(_), do: false
end

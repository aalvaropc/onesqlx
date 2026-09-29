defmodule Onesqlx.Authorization do
  @moduledoc """
  Role-based authorization helpers.

  Owners and admins can manage any resource in their workspace.
  Members can only manage resources they created (matching `user_id`).
  """

  alias Onesqlx.Accounts.Scope

  @doc """
  Returns `true` if the scope has permission to manage (update/delete) the resource.

  Owners and admins can manage any resource. Members can only manage their
  own. Viewers manage nothing.
  """
  def can_manage?(%Scope{role: "viewer"}, _resource), do: false
  def can_manage?(%Scope{role: role}, _resource) when role in ["owner", "admin"], do: true
  def can_manage?(%Scope{user: user}, %{user_id: uid}), do: user.id == uid
  def can_manage?(_, _), do: false

  @doc """
  Returns `true` if the scope may create resources in the workspace.

  Everyone but viewers: viewers run queries and read dashboards, but do
  not add saved queries, dashboards, schedules, snippets, or sources.
  """
  def can_create?(%Scope{role: "viewer"}), do: false
  def can_create?(%Scope{}), do: true

  @doc """
  Raises `Ecto.NoResultsError` unless the scope may create resources.
  """
  def authorize_create!(%Scope{} = scope, queryable) do
    unless can_create?(scope) do
      raise Ecto.NoResultsError, queryable: queryable
    end

    scope
  end

  @doc """
  Raises `Ecto.NoResultsError` if the scope cannot manage the resource.
  """
  def authorize_manage!(%Scope{} = scope, resource) do
    unless can_manage?(scope, resource) do
      raise Ecto.NoResultsError, queryable: resource.__struct__
    end

    resource
  end
end

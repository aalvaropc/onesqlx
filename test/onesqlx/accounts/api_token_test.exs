defmodule Onesqlx.Accounts.ApiTokenTest do
  use Onesqlx.DataCase, async: true

  alias Onesqlx.Accounts.ApiToken

  import Onesqlx.AccountsFixtures

  setup do
    scope = user_scope_fixture()
    %{scope: scope, user: scope.user, workspace: scope.workspace}
  end

  describe "build_token/3" do
    test "returns raw token and struct with hash", %{user: user, workspace: workspace} do
      {raw, token} = ApiToken.build_token(user, workspace, "test-token")

      assert is_binary(raw)
      assert byte_size(raw) > 20
      assert token.user_id == user.id
      assert token.workspace_id == workspace.id
      assert token.name == "test-token"
      assert is_binary(token.token_hash)
      assert token.token_hash == :crypto.hash(:sha256, raw)
    end
  end

  describe "verify_token/1" do
    test "verifies valid token", %{user: user, workspace: workspace} do
      {raw, token} = ApiToken.build_token(user, workspace, "verify-test")
      {:ok, _} = token |> ApiToken.changeset(%{}) |> Repo.insert()

      assert {:ok, found_user, found_workspace} = ApiToken.verify_token(raw)
      assert found_user.id == user.id
      assert found_workspace.id == workspace.id
    end

    test "rejects invalid token" do
      assert :error = ApiToken.verify_token("totally-bogus-token")
    end

    test "rejects expired token", %{user: user, workspace: workspace} do
      {raw, token} = ApiToken.build_token(user, workspace, "expired-test")
      past = DateTime.add(DateTime.utc_now(:second), -3600, :second)

      token
      |> ApiToken.changeset(%{expires_at: past})
      |> Repo.insert!()

      assert :error = ApiToken.verify_token(raw)
    end

    test "accepts token without expiry", %{user: user, workspace: workspace} do
      {raw, token} = ApiToken.build_token(user, workspace, "no-expiry")
      {:ok, _} = token |> ApiToken.changeset(%{}) |> Repo.insert()

      assert {:ok, _, _} = ApiToken.verify_token(raw)
    end
  end

  describe "get_scope/1" do
    test "returns scope for valid token", %{user: user, workspace: workspace} do
      {raw, token} = ApiToken.build_token(user, workspace, "scope-test")
      {:ok, _} = token |> ApiToken.changeset(%{}) |> Repo.insert()

      assert {:ok, scope} = ApiToken.get_scope(raw)
      assert scope.user.id == user.id
      assert scope.workspace.id == workspace.id
    end

    test "returns error for invalid token" do
      assert :error = ApiToken.get_scope("bad-token")
    end
  end

  describe "changeset/2" do
    test "validates required name", %{user: user, workspace: workspace} do
      {_raw, token} = ApiToken.build_token(user, workspace, "")

      changeset = ApiToken.changeset(token, %{name: ""})
      assert errors_on(changeset).name
    end

    test "enforces unique name per user", %{user: user, workspace: workspace} do
      {_raw1, t1} = ApiToken.build_token(user, workspace, "dup-name")
      {:ok, _} = t1 |> ApiToken.changeset(%{}) |> Repo.insert()

      {_raw2, t2} = ApiToken.build_token(user, workspace, "dup-name")
      assert {:error, changeset} = t2 |> ApiToken.changeset(%{}) |> Repo.insert()
      assert "has already been taken" in errors_on(changeset).name
    end
  end
end

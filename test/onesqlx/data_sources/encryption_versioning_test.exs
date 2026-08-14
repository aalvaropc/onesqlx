defmodule Onesqlx.DataSources.EncryptionVersioningTest do
  # async: false — tests set the global :encryption_key application env
  use Onesqlx.DataCase, async: false

  import Onesqlx.AccountsFixtures
  import Onesqlx.DataSourcesFixtures

  alias Onesqlx.DataSources
  alias Onesqlx.DataSources.Encryption

  @key :crypto.strong_rand_bytes(32)

  setup do
    original = Application.fetch_env(:onesqlx, :encryption_key)

    on_exit(fn ->
      case original do
        {:ok, value} -> Application.put_env(:onesqlx, :encryption_key, value)
        :error -> Application.delete_env(:onesqlx, :encryption_key)
      end
    end)

    :ok
  end

  defp with_key, do: Application.put_env(:onesqlx, :encryption_key, @key)
  defp without_key, do: Application.delete_env(:onesqlx, :encryption_key)

  describe "without a dedicated key (legacy v1)" do
    test "roundtrips with the SECRET_KEY_BASE-derived key" do
      without_key()

      ciphertext = Encryption.encrypt("s3cret")
      refute String.starts_with?(ciphertext, "v2:")
      assert Encryption.decrypt(ciphertext) == "s3cret"
      refute Encryption.current_version?(ciphertext)
    end
  end

  describe "with a dedicated key (v2)" do
    test "encrypts to the v2 format and roundtrips" do
      with_key()

      ciphertext = Encryption.encrypt("s3cret")
      assert String.starts_with?(ciphertext, "v2:")
      assert Encryption.decrypt(ciphertext) == "s3cret"
      assert Encryption.current_version?(ciphertext)
    end

    test "still decrypts legacy v1 ciphertexts" do
      without_key()
      legacy = Encryption.encrypt("old-secret")

      with_key()
      assert Encryption.decrypt(legacy) == "old-secret"
      refute Encryption.current_version?(legacy)
    end

    test "decrypting v2 without the key raises" do
      with_key()
      ciphertext = Encryption.encrypt("s3cret")

      without_key()

      assert_raise RuntimeError, ~r/ENCRYPTION_KEY is not configured/, fn ->
        Encryption.decrypt(ciphertext)
      end
    end

    test "tampered or malformed ciphertexts return :error" do
      with_key()

      assert Encryption.decrypt("v2:" <> :crypto.strong_rand_bytes(40)) == :error
      assert Encryption.decrypt("too-short") == :error
    end
  end

  describe "rotate_credential_encryption/0" do
    test "raises without a dedicated key configured" do
      without_key()

      assert_raise RuntimeError, ~r/ENCRYPTION_KEY must be configured/, fn ->
        DataSources.rotate_credential_encryption()
      end
    end

    test "re-encrypts legacy credentials and skips current ones" do
      without_key()
      scope = user_scope_fixture()
      ds = data_source_fixture(scope, %{name: "legacy-ds", password: "legacy-pass"})
      refute String.starts_with?(ds.encrypted_password, "v2:")

      with_key()
      assert %{rotated: 1, skipped: 0, failed: 0} = DataSources.rotate_credential_encryption()

      rotated = Repo.get!(Onesqlx.DataSources.DataSource, ds.id)
      assert String.starts_with?(rotated.encrypted_password, "v2:")
      assert DataSources.decrypt_password(rotated) == "legacy-pass"

      # Second run: nothing left to rotate
      assert %{rotated: 0, skipped: 1, failed: 0} = DataSources.rotate_credential_encryption()
    end
  end
end

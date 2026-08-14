defmodule Onesqlx.DataSources.Encryption do
  @moduledoc """
  AES-256-GCM encryption for data source credentials, with key versioning.

  Two ciphertext formats coexist:

    * **v2** (current): `"v2:" <> iv(12) <> tag(16) <> ciphertext`, using the
      dedicated key from the `ENCRYPTION_KEY` env var (base64-encoded 32
      bytes, wired to `:onesqlx, :encryption_key` in `config/runtime.exs`).
      Used for all new encryptions when the key is configured.
    * **v1** (legacy): raw `iv(12) <> tag(16) <> ciphertext`, key derived
      from `SECRET_KEY_BASE` via SHA-256. Always decryptable; only used for
      new encryptions when no dedicated key is configured.

  With a dedicated key configured, rotating `SECRET_KEY_BASE` no longer
  invalidates stored credentials. Migrate existing v1 rows with
  `mix onesqlx.rotate_encryption` (or `Onesqlx.Release.rotate_encryption/0`
  in a release).
  """

  @aad "onesqlx_data_source_password"
  @iv_length 12
  @tag_length 16
  @v2_prefix "v2:"

  @doc """
  Encrypts plaintext using AES-256-GCM: v2 format with the dedicated key
  when configured, legacy v1 format otherwise.
  """
  def encrypt(plaintext) when is_binary(plaintext) do
    case dedicated_key() do
      nil -> do_encrypt(derive_legacy_key(), plaintext, "")
      key -> do_encrypt(key, plaintext, @v2_prefix)
    end
  end

  @doc """
  Decrypts a binary produced by `encrypt/1`, from either format.

  Returns the plaintext, or `:error` when the ciphertext cannot be
  authenticated or is malformed.
  """
  def decrypt(@v2_prefix <> rest), do: do_decrypt(dedicated_key!(), rest)
  def decrypt(legacy) when is_binary(legacy), do: do_decrypt(derive_legacy_key(), legacy)

  @doc """
  Whether the ciphertext already uses the current key: true only for v2
  ciphertexts while a dedicated key is configured.
  """
  def current_version?(@v2_prefix <> _rest), do: dedicated_key() != nil
  def current_version?(_other), do: false

  defp do_encrypt(key, plaintext, prefix) do
    iv = :crypto.strong_rand_bytes(@iv_length)

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, @aad, @tag_length, true)

    prefix <> iv <> tag <> ciphertext
  end

  defp do_decrypt(
         key,
         <<iv::binary-size(@iv_length), tag::binary-size(@tag_length), ciphertext::binary>>
       ) do
    :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, @aad, tag, false)
  end

  defp do_decrypt(_key, _malformed), do: :error

  defp dedicated_key do
    Application.get_env(:onesqlx, :encryption_key)
  end

  defp dedicated_key! do
    dedicated_key() ||
      raise "a v2-encrypted credential exists but ENCRYPTION_KEY is not configured"
  end

  defp derive_legacy_key do
    secret_key_base =
      Application.get_env(:onesqlx, OnesqlxWeb.Endpoint)[:secret_key_base] ||
        raise "SECRET_KEY_BASE not configured"

    :crypto.hash(:sha256, secret_key_base)
  end
end

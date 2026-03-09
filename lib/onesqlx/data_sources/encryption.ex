defmodule Onesqlx.DataSources.Encryption do
  @moduledoc """
  AES-256-GCM encryption for data source credentials.

  Derives the encryption key from `SECRET_KEY_BASE` via SHA-256.
  """

  @aad "onesqlx_data_source_password"
  @iv_length 12
  @tag_length 16

  @doc """
  Encrypts plaintext using AES-256-GCM.

  Returns a binary containing `iv(12) <> tag(16) <> ciphertext`.
  """
  def encrypt(plaintext) when is_binary(plaintext) do
    key = derive_key()
    iv = :crypto.strong_rand_bytes(@iv_length)

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, @aad, @tag_length, true)

    iv <> tag <> ciphertext
  end

  @doc """
  Decrypts a binary produced by `encrypt/1`.

  Returns the original plaintext.
  """
  def decrypt(<<iv::binary-size(@iv_length), tag::binary-size(@tag_length), ciphertext::binary>>) do
    key = derive_key()

    :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, @aad, tag, false)
  end

  defp derive_key do
    secret_key_base =
      Application.get_env(:onesqlx, OnesqlxWeb.Endpoint)[:secret_key_base] ||
        raise "SECRET_KEY_BASE not configured"

    :crypto.hash(:sha256, secret_key_base)
  end
end

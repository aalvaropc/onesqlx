defmodule Onesqlx.DataSources.EncryptionTest do
  use ExUnit.Case, async: true

  alias Onesqlx.DataSources.Encryption

  describe "encrypt/1 and decrypt/1" do
    test "round-trips plaintext" do
      plaintext = "my_secret_password"
      encrypted = Encryption.encrypt(plaintext)
      assert Encryption.decrypt(encrypted) == plaintext
    end

    test "encrypted output differs from plaintext" do
      plaintext = "my_secret_password"
      encrypted = Encryption.encrypt(plaintext)
      refute encrypted == plaintext
    end

    test "produces different ciphertext each time (random IV)" do
      plaintext = "my_secret_password"
      encrypted_1 = Encryption.encrypt(plaintext)
      encrypted_2 = Encryption.encrypt(plaintext)
      refute encrypted_1 == encrypted_2
    end

    test "detects tampered ciphertext" do
      plaintext = "my_secret_password"
      encrypted = Encryption.encrypt(plaintext)

      # Flip a byte in the ciphertext portion (after IV + tag = 28 bytes)
      <<iv_tag::binary-size(28), rest::binary>> = encrypted
      tampered = iv_tag <> :crypto.exor(rest, <<1>> <> :binary.copy(<<0>>, byte_size(rest) - 1))

      assert :error == Encryption.decrypt(tampered)
    end
  end
end

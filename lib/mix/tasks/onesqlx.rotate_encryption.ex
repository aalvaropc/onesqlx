defmodule Mix.Tasks.Onesqlx.RotateEncryption do
  @shortdoc "Re-encrypts data source credentials with the dedicated ENCRYPTION_KEY"

  @moduledoc """
  Re-encrypts every stored data source credential to the current (v2)
  format using the dedicated `ENCRYPTION_KEY`.

      ENCRYPTION_KEY=<base64 32 bytes> mix onesqlx.rotate_encryption

  After all credentials report as rotated or skipped, `SECRET_KEY_BASE`
  can be rotated freely without invalidating them. In a release, use
  `bin/onesqlx eval Onesqlx.Release.rotate_encryption` instead.
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    %{rotated: rotated, skipped: skipped, failed: failed} =
      Onesqlx.DataSources.rotate_credential_encryption()

    Mix.shell().info("Rotated #{rotated}, already current or empty #{skipped}, failed #{failed}")

    if failed > 0 do
      Mix.shell().error(
        "#{failed} credential(s) could not be decrypted with the current keys; " <>
          "their data sources need the password re-entered manually."
      )
    end
  end
end

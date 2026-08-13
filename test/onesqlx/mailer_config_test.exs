defmodule Onesqlx.MailerConfigTest do
  use ExUnit.Case, async: true

  alias Onesqlx.MailerConfig

  describe "resolve/1" do
    test "returns :local when no provider env vars are set" do
      assert MailerConfig.resolve(%{}) == :local
    end

    test "ignores empty-string values" do
      assert MailerConfig.resolve(%{"SMTP_HOST" => "", "RESEND_API_KEY" => ""}) == :local
    end

    test "picks SMTP when SMTP_HOST is set" do
      {adapter, opts} =
        MailerConfig.resolve(%{
          "SMTP_HOST" => "smtp.example.com",
          "SMTP_USERNAME" => "mailer",
          "SMTP_PASSWORD" => "secret"
        })

      assert adapter == Swoosh.Adapters.SMTP
      assert opts[:relay] == "smtp.example.com"
      assert opts[:port] == 587
      assert opts[:username] == "mailer"
      assert opts[:password] == "secret"
      assert opts[:auth] == :always
      assert opts[:tls] == :always
    end

    test "SMTP without credentials disables auth" do
      {_adapter, opts} = MailerConfig.resolve(%{"SMTP_HOST" => "relay.internal"})

      assert opts[:auth] == :never
      assert opts[:username] == nil
    end

    test "SMTP respects custom port and disabled TLS" do
      {_adapter, opts} =
        MailerConfig.resolve(%{
          "SMTP_HOST" => "relay.internal",
          "SMTP_PORT" => "2525",
          "SMTP_TLS" => "false"
        })

      assert opts[:port] == 2525
      assert opts[:tls] == :never
    end

    test "picks Resend when only RESEND_API_KEY is set" do
      assert {Swoosh.Adapters.Resend, opts} =
               MailerConfig.resolve(%{"RESEND_API_KEY" => "re_123"})

      assert opts[:api_key] == "re_123"
    end

    test "SMTP wins over Resend when both are set" do
      assert {Swoosh.Adapters.SMTP, _opts} =
               MailerConfig.resolve(%{
                 "SMTP_HOST" => "smtp.example.com",
                 "RESEND_API_KEY" => "re_123"
               })
    end
  end

  describe "sender/0" do
    test "falls back to the default sender when :mail_from is not configured" do
      assert {name, email} = MailerConfig.sender()
      assert is_binary(name)
      assert String.contains?(email, "@")
    end

    test "returns the configured :mail_from tuple" do
      original = Application.fetch_env(:onesqlx, :mail_from)
      Application.put_env(:onesqlx, :mail_from, {"Acme", "noreply@acme.io"})

      on_exit(fn ->
        case original do
          {:ok, value} -> Application.put_env(:onesqlx, :mail_from, value)
          :error -> Application.delete_env(:onesqlx, :mail_from)
        end
      end)

      assert MailerConfig.sender() == {"Acme", "noreply@acme.io"}
    end
  end
end

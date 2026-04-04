defmodule Onesqlx.Scheduling.NotifierTest do
  use ExUnit.Case, async: true

  alias Onesqlx.Scheduling.Notifier

  describe "deliver_run_result/2" do
    test "returns :ok when notify_email is nil" do
      sq = %{notify_email: nil, name: "Test"}
      assert :ok = Notifier.deliver_run_result(sq, %{status: "success"})
    end

    test "returns :ok when notify_email is empty string" do
      sq = %{notify_email: "", name: "Test"}
      assert :ok = Notifier.deliver_run_result(sq, %{status: "success"})
    end

    test "delivers email when notify_email is set" do
      sq = %{notify_email: "user@example.com", name: "Daily Report"}

      run_attrs = %{
        status: "success",
        duration_ms: 42,
        row_count: 10
      }

      assert {:ok, email} = Notifier.deliver_run_result(sq, run_attrs)
      assert email.subject =~ "Daily Report"
      assert email.subject =~ "success"
      assert email.text_body =~ "Duration: 42ms"
      assert email.text_body =~ "Rows: 10"
    end

    test "includes error message for failed runs" do
      sq = %{notify_email: "user@example.com", name: "Broken Query"}

      run_attrs = %{
        status: "error",
        error_message: "relation does not exist"
      }

      assert {:ok, email} = Notifier.deliver_run_result(sq, run_attrs)
      assert email.subject =~ "error"
      assert email.text_body =~ "relation does not exist"
    end
  end

  describe "deliver_webhook/2" do
    test "returns :ok when webhook_url is nil" do
      sq = %{webhook_url: nil, name: "Test"}
      assert :ok = Notifier.deliver_webhook(sq, %{status: "success"})
    end

    test "returns :ok when webhook_url is empty string" do
      sq = %{webhook_url: "", name: "Test"}
      assert :ok = Notifier.deliver_webhook(sq, %{status: "success"})
    end

    test "returns :ok when webhook_url key is missing" do
      sq = %{name: "Test"}
      assert :ok = Notifier.deliver_webhook(sq, %{status: "success"})
    end
  end
end

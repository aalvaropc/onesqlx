defmodule Onesqlx.Scheduling.CronParserTest do
  use ExUnit.Case, async: true

  alias Onesqlx.Scheduling.CronParser

  describe "valid?/1" do
    test "accepts every-minute pattern" do
      assert CronParser.valid?("* * * * *")
    end

    test "accepts hourly pattern" do
      assert CronParser.valid?("0 * * * *")
    end

    test "accepts daily-at-midnight pattern" do
      assert CronParser.valid?("0 0 * * *")
    end

    test "accepts weekly-on-monday pattern" do
      assert CronParser.valid?("0 0 * * 1")
    end

    test "accepts every-5-minutes pattern" do
      assert CronParser.valid?("*/5 * * * *")
    end

    test "accepts range pattern" do
      assert CronParser.valid?("0 9-17 * * *")
    end

    test "accepts comma-separated list" do
      assert CronParser.valid?("0 0 1,15 * *")
    end

    test "accepts complex pattern" do
      assert CronParser.valid?("*/15 9-17 * 1-6 1-5")
    end

    test "rejects minute out of range (60)" do
      refute CronParser.valid?("60 * * * *")
    end

    test "rejects hour out of range (25)" do
      refute CronParser.valid?("* 25 * * *")
    end

    test "rejects non-cron text" do
      refute CronParser.valid?("not a cron")
    end

    test "rejects too few fields" do
      refute CronParser.valid?("* * *")
    end

    test "rejects too many fields" do
      refute CronParser.valid?("* * * * * *")
    end

    test "rejects empty string" do
      refute CronParser.valid?("")
    end

    test "rejects nil" do
      refute CronParser.valid?(nil)
    end

    test "rejects day-of-month 0" do
      refute CronParser.valid?("0 0 0 * *")
    end

    test "rejects month 0" do
      refute CronParser.valid?("0 0 * 0 *")
    end

    test "rejects month 13" do
      refute CronParser.valid?("0 0 * 13 *")
    end
  end

  describe "next_occurrence/2" do
    test "every-5-minutes advances correctly" do
      from = ~U[2026-03-25 10:07:00Z]
      assert {:ok, next} = CronParser.next_occurrence("*/5 * * * *", from)
      assert next == ~U[2026-03-25 10:10:00Z]
    end

    test "daily-at-midnight advances to next day" do
      from = ~U[2026-03-25 00:00:00Z]
      assert {:ok, next} = CronParser.next_occurrence("0 0 * * *", from)
      assert next == ~U[2026-03-26 00:00:00Z]
    end

    test "weekly-on-monday finds next monday" do
      # 2026-03-25 is a Wednesday
      from = ~U[2026-03-25 10:00:00Z]
      assert {:ok, next} = CronParser.next_occurrence("0 0 * * 1", from)
      assert next.hour == 0
      assert next.minute == 0
      assert Date.day_of_week(next) == 1
      assert DateTime.compare(next, from) == :gt
    end

    test "does not return the current time if it matches" do
      # 10:00 matches "0 * * * *"
      from = ~U[2026-03-25 10:00:00Z]
      assert {:ok, next} = CronParser.next_occurrence("0 * * * *", from)
      assert DateTime.compare(next, from) == :gt
    end

    test "handles specific day-of-month" do
      from = ~U[2026-03-25 00:00:00Z]
      assert {:ok, next} = CronParser.next_occurrence("0 0 1 * *", from)
      assert next.day == 1
      assert DateTime.compare(next, from) == :gt
    end

    test "returns error for invalid expression" do
      assert {:error, _} = CronParser.next_occurrence("invalid", ~U[2026-03-25 10:00:00Z])
    end

    test "hourly pattern advances to next hour" do
      from = ~U[2026-03-25 10:30:00Z]
      assert {:ok, next} = CronParser.next_occurrence("0 * * * *", from)
      assert next == ~U[2026-03-25 11:00:00Z]
    end
  end
end

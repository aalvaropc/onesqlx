defmodule OnesqlxWeb.SqlEditorLive.TabsTest do
  use ExUnit.Case, async: true

  alias OnesqlxWeb.SqlEditorLive.Tabs

  describe "new/1" do
    test "builds a fresh tab with defaults" do
      tab = Tabs.new("Tab 1")

      assert tab.name == "Tab 1"
      assert tab.sql == ""
      assert tab.data_source_id == nil
      refute tab.running?
      assert tab.active_result_tab == :results
      assert tab.row_limit == 1000
      assert tab.sort_direction == :asc
      assert {:ok, _} = Ecto.UUID.cast(tab.id)
    end

    test "each tab gets a unique id" do
      assert Tabs.new("a").id != Tabs.new("b").id
    end
  end

  describe "next_active_after_close/3" do
    test "keeps the active tab when closing another one" do
      assert Tabs.next_active_after_close(["a", "b", "c"], "c", "a") == "c"
    end

    test "activates the tab at the closed position" do
      assert Tabs.next_active_after_close(["a", "b", "c"], "b", "b") == "c"
    end

    test "activates the new last tab when closing the last one" do
      assert Tabs.next_active_after_close(["a", "b", "c"], "c", "c") == "b"
    end

    test "closing the only remaining neighbor still yields a tab" do
      assert Tabs.next_active_after_close(["a", "b"], "a", "a") == "b"
    end
  end
end

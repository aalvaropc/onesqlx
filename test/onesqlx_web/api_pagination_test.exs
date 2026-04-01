defmodule OnesqlxWeb.ApiPaginationTest do
  use ExUnit.Case, async: true

  alias OnesqlxWeb.ApiPagination

  describe "extract_pagination/1" do
    test "returns defaults when no params" do
      assert [limit: 50, offset: 0] = ApiPagination.extract_pagination(%{})
    end

    test "parses valid integer strings" do
      assert [limit: 10, offset: 5] =
               ApiPagination.extract_pagination(%{"limit" => "10", "offset" => "5"})
    end

    test "clamps limit to max 200" do
      assert [limit: 200, offset: 0] = ApiPagination.extract_pagination(%{"limit" => "999"})
    end

    test "clamps limit to min 1" do
      assert [limit: 1, offset: 0] = ApiPagination.extract_pagination(%{"limit" => "0"})
    end

    test "floors offset at 0" do
      assert [limit: 50, offset: 0] = ApiPagination.extract_pagination(%{"offset" => "-5"})
    end

    test "uses defaults for non-numeric strings" do
      assert [limit: 50, offset: 0] =
               ApiPagination.extract_pagination(%{"limit" => "abc", "offset" => "xyz"})
    end
  end

  describe "pagination_meta/3" do
    test "builds metadata map" do
      assert %{limit: 50, offset: 0, total: 123} = ApiPagination.pagination_meta(50, 0, 123)
    end
  end
end

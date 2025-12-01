defmodule Fixtures.Stdlib do
  @moduledoc """
  Test fixture for stdlib runtime functions (Enum, String, Map)
  Tests that imports are generated correctly.
  """

  # ========== Enum Functions ==========

  def enum_product do
    Enum.product([1, 2, 3, 4, 5])
  end

  def enum_frequencies do
    Enum.frequencies(["a", "b", "a", "c", "b", "a"])
  end

  def enum_group_by do
    Enum.group_by([1, 2, 3, 4, 5, 6], fn x -> rem(x, 2) end)
  end

  def enum_chunk_every do
    Enum.chunk_every([1, 2, 3, 4, 5, 6, 7], 3)
  end

  def enum_zip_with do
    Enum.zip_with([1, 2, 3], [4, 5, 6], fn a, b -> a + b end)
  end

  def enum_min_max do
    Enum.min_max([3, 1, 4, 1, 5, 9, 2, 6])
  end

  # ========== String Functions ==========

  def string_trim do
    String.trim("  hello  ")
  end

  def string_pad_leading do
    String.pad_leading("42", 5, "0")
  end

  def string_pad_trailing do
    String.pad_trailing("hello", 10, "!")
  end

  def string_replace_prefix do
    String.replace_prefix("Mr. Smith", "Mr. ", "Dr. ")
  end

  def string_graphemes do
    String.graphemes("hello")
  end

  # ========== Map Functions ==========

  def map_filter do
    map = %{a: 1, b: 2, c: 3, d: 4}
    Map.filter(map, fn _k, v -> v > 2 end)
  end

  def map_reject do
    map = %{a: 1, b: 2, c: 3, d: 4}
    Map.reject(map, fn _k, v -> v <= 2 end)
  end

  def map_split do
    map = %{a: 1, b: 2, c: 3, d: 4}
    Map.split(map, [:a, :c])
  end

  def map_take do
    map = %{a: 1, b: 2, c: 3, d: 4}
    Map.take(map, [:a, :c])
  end

  def map_drop do
    map = %{a: 1, b: 2, c: 3, d: 4}
    Map.drop(map, [:b, :d])
  end

  # ========== Combined Usage ==========

  def combined_usage(items) do
    items
    |> Enum.filter(fn x -> x > 0 end)
    |> Enum.map(fn x -> String.upcase(to_string(x)) end)
    |> Enum.join(", ")
  end
end

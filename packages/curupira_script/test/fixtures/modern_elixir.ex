defmodule Fixtures.ModernElixir do
  @moduledoc """
  Test fixture: Module with then/2 and tap/2 (Elixir 1.12+ features).
  """

  # then/2 examples
  def use_then(value) do
    value
    |> then(fn x -> x * 2 end)
  end

  def use_then_with_capture(value) do
    value
    |> then(&double/1)
  end

  # tap/2 examples
  def use_tap(value) do
    value
    |> tap(fn x -> x * 2 end)  # Side effect, returns value
  end

  def chain_then_and_tap(value) do
    value
    |> tap(fn x -> x + 1 end)   # Returns value
    |> then(fn x -> x * 2 end)  # Returns x * 2
  end

  # Helper
  defp double(x), do: x * 2

  # Stepped ranges (Elixir 1.12+)
  def regular_range do
    1..10
  end

  def stepped_range do
    1..10//2
  end

  def stepped_range_by_ten do
    0..100//10
  end

  def descending_stepped_range do
    10..1//-1
  end

  def descending_stepped_range_by_two do
    10..1//-2
  end

  def use_range_in_enum do
    1..10//2
    |> Enum.map(fn x -> x * 2 end)
  end

  # is_non_struct_map/1 guard (Elixir 1.17+)
  def accepts_plain_map(data) when is_non_struct_map(data) do
    {:ok, "plain map"}
  end

  def accepts_plain_map(_data) do
    {:error, "not a plain map"}
  end

  def process_map_not_struct(data) when is_non_struct_map(data) do
    Map.put(data, :processed, true)
  end

  def process_map_not_struct(_data) do
    {:error, "requires plain map"}
  end

  # Test guard with actual map
  def test_guard_with_map do
    accepts_plain_map(%{a: 1, b: 2})
  end

  # Test guard with struct (should not match)
  def test_guard_with_struct do
    {:error, "struct not accepted"}
  end

  # Duration type (Elixir 1.17+)
  def create_duration_hours do
    Duration.new!(hour: 2)
  end

  def create_duration_days do
    Duration.new!(day: 7)
  end

  def create_duration_complex do
    Duration.new!(day: 1, hour: 2, minute: 30)
  end

  def create_duration_all_units do
    Duration.new!(
      year: 1,
      month: 2,
      week: 3,
      day: 4,
      hour: 5,
      minute: 6,
      second: 7,
      microsecond: 8
    )
  end

  def create_duration_empty do
    Duration.new!([])
  end

  def create_duration_negative do
    Duration.new!(day: -1, hour: -2)
  end

  def create_duration_microseconds do
    Duration.new!(microsecond: 500000)
  end
end

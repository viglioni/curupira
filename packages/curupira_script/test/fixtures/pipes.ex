defmodule Fixtures.Pipes do
  @moduledoc """
  Test fixture: Module with pipe operator usage.
  """

  def transform(x) do
    x
    |> add_one()
    |> multiply_two()
  end

  defp add_one(n), do: n + 1
  defp multiply_two(n), do: n * 2
end

defmodule Fixtures.DataTypes do
  @moduledoc """
  Test fixture: Module with functions returning various data types.
  """

  def integers, do: 42
  def floats, do: 3.14
  def strings, do: "hello"
  def atoms, do: :ok
  def lists, do: [1, 2, 3]
  def tuples, do: {1, 2}
  def maps, do: %{key: "value"}
end

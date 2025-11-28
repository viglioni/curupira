defmodule Fixtures.WithArgs do
  @moduledoc """
  Test fixture: Module with function that takes arguments and uses string interpolation.
  """

  def greet(name), do: "Hello, #{name}!"
end

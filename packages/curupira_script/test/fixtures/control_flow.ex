defmodule Fixtures.ControlFlow do
  @moduledoc """
  Test fixture: Module with control flow expressions.
  """

  def check(x) do
    if x > 0 do
      :positive
    else
      :negative
    end
  end

  def classify(x) do
    case x do
      0 -> :zero
      n when n > 0 -> :positive
      _ -> :negative
    end
  end
end

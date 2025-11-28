defmodule Fixtures.PatternMatch do
  @moduledoc """
  Test fixture: Module with pattern matching functions.
  """

  def first([head | _tail]), do: head
  def is_empty?([]), do: true
  def is_empty?(_), do: false
end

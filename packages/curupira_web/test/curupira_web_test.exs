defmodule CurupiraWebTest do
  use ExUnit.Case
  doctest CurupiraWeb

  test "greets the world" do
    assert CurupiraWeb.hello() == :world
  end
end

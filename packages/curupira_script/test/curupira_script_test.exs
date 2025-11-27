defmodule CurupiraScriptTest do
  use ExUnit.Case
  doctest CurupiraScript

  describe "version/0" do
    test "returns version string" do
      assert is_binary(CurupiraScript.version())
    end
  end

  describe "compile/2" do
    test "returns not implemented error (Phase 0)" do
      assert {:error, :not_implemented} = CurupiraScript.compile(TestModule)
    end
  end
end

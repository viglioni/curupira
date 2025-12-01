defmodule FFITest do
  use ExUnit.Case

  alias CurupiraJS.Compiler

  setup_all do
    # Ensure FFI example is compiled
    Code.compiler_options(ignore_module_conflict: true)
    Code.compile_file("test/fixtures/ffi_example.ex")
    :ok
  end

  describe "FFI Compilation" do
    test "compiles FFI module successfully" do
      assert {:ok, result} = Compiler.compile(Fixtures.FFIExample, source_maps: false)
      assert is_map(result)
      assert Map.has_key?(result, :output_files)
      assert length(result.output_files) == 1
    end

    test "generates JavaScript for external JS path" do
      {:ok, result} = Compiler.compile(Fixtures.FFIExample, source_maps: false)
      js_code = hd(result.output_files).content

      # Should contain Math.random call
      assert js_code =~ "Math.random"
    end

    test "generates JavaScript for inline JS" do
      {:ok, result} = Compiler.compile(Fixtures.FFIExample, source_maps: false)
      js_code = hd(result.output_files).content

      # Should contain inline JS functions
      assert js_code =~ "(a, b) => a + b"
    end

    test "wraps returns with {:ok, _} type" do
      {:ok, result} = Compiler.compile(Fixtures.FFIExample, source_maps: false)
      js_code = hd(result.output_files).content

      # Should wrap with [Symbol.for("ok"), result]
      assert js_code =~ "Symbol.for(\"ok\")"
    end

    test "handles {:result, _} return type" do
      {:ok, result} = Compiler.compile(Fixtures.FFIExample, source_maps: false)
      js_code = hd(result.output_files).content

      # Should check result.ok and return appropriate tuple
      assert js_code =~ "_result.ok"
      assert js_code =~ "Symbol.for(\"error\")"
    end
  end
end

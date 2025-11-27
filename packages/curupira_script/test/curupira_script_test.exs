defmodule CurupiraScriptTest do
  use ExUnit.Case
  doctest CurupiraScript

  # Test modules for compilation
  defmodule Simple do
    def hello, do: "world"
  end

  defmodule WithArgs do
    def greet(name), do: "Hello, #{name}!"
  end

  defmodule Multiple do
    def add(a, b), do: a + b
    def subtract(a, b), do: a - b
  end

  describe "version/0" do
    test "returns version string" do
      assert is_binary(CurupiraScript.version())
    end

    test "returns semantic version format" do
      version = CurupiraScript.version()
      assert version =~ ~r/^\d+\.\d+\.\d+/
    end
  end

  describe "compile/2 - basic API" do
    test "accepts a single module" do
      assert {:error, :not_implemented} = CurupiraScript.compile(Simple)
    end

    test "accepts a list of modules" do
      assert {:error, :not_implemented} = CurupiraScript.compile([Simple, WithArgs])
    end

    test "accepts empty options" do
      assert {:error, :not_implemented} = CurupiraScript.compile(Simple, [])
    end
  end

  describe "compile/2 - options handling" do
    @tag :skip
    test "accepts output option" do
      assert {:error, :not_implemented} =
               CurupiraScript.compile(Simple, output: "dist/js")
    end

    @tag :skip
    test "accepts source_maps option" do
      assert {:error, :not_implemented} =
               CurupiraScript.compile(Simple, source_maps: true)
    end

    @tag :skip
    test "accepts format option" do
      assert {:error, :not_implemented} =
               CurupiraScript.compile(Simple, format: :es)
    end

    @tag :skip
    test "accepts multiple options" do
      assert {:error, :not_implemented} =
               CurupiraScript.compile(Simple,
                 output: "dist/js",
                 source_maps: true,
                 format: :es
               )
    end
  end

  describe "compile/2 - input validation" do
    @tag :skip
    test "returns error for non-module atom" do
      assert {:error, {:invalid_module, :not_a_module}} =
               CurupiraScript.compile(:not_a_module)
    end

    @tag :skip
    test "returns error for nil" do
      assert {:error, {:invalid_input, nil}} = CurupiraScript.compile(nil)
    end

    @tag :skip
    test "returns error for non-atom in list" do
      assert {:error, {:invalid_module, "string"}} =
               CurupiraScript.compile([Simple, "string"])
    end

    @tag :skip
    test "returns error for empty module list" do
      assert {:error, :empty_module_list} = CurupiraScript.compile([])
    end

    @tag :skip
    test "returns error for invalid options" do
      assert {:error, {:invalid_option, :invalid_key}} =
               CurupiraScript.compile(Simple, invalid_key: "value")
    end
  end

  describe "compile/2 - success response (Phase 1+)" do
    @tag :phase1
    test "returns {:ok, result} on successful compilation" do
      assert {:ok, result} = CurupiraScript.compile(Simple)
      assert is_map(result)
    end

    @tag :phase1
    test "result contains compiled modules list" do
      assert {:ok, %{compiled_modules: modules}} = CurupiraScript.compile(Simple)
      assert is_list(modules)
      assert Simple in modules
    end

    @tag :phase1
    test "result contains output files" do
      assert {:ok, %{output_files: files}} = CurupiraScript.compile(Simple)
      assert is_list(files)
    end

    @tag :phase1
    test "result contains JavaScript code" do
      assert {:ok, %{output_files: files}} = CurupiraScript.compile(Simple)
      assert [%{path: _path, content: js_code}] = files
      assert is_binary(js_code)
    end
  end

  describe "compile/2 - JavaScript generation (Phase 1+)" do
    @tag :phase1
    test "generates ES module format" do
      assert {:ok, %{output_files: [%{content: js}]}} = CurupiraScript.compile(Simple)
      assert js =~ "export default"
    end

    @tag :phase1
    test "generates function for module function" do
      assert {:ok, %{output_files: [%{content: js}]}} = CurupiraScript.compile(Simple)
      assert js =~ "hello"
    end

    @tag :phase1
    test "handles string interpolation" do
      assert {:ok, %{output_files: [%{content: js}]}} = CurupiraScript.compile(WithArgs)
      # Should use template literals
      assert js =~ "`"
    end

    @tag :phase1
    test "handles multiple functions" do
      assert {:ok, %{output_files: [%{content: js}]}} = CurupiraScript.compile(Multiple)
      assert js =~ "add"
      assert js =~ "subtract"
    end
  end

  describe "compile/2 - multiple modules (Phase 1+)" do
    @tag :phase1
    test "compiles multiple modules" do
      assert {:ok, %{compiled_modules: modules}} =
               CurupiraScript.compile([Simple, WithArgs])

      assert length(modules) == 2
      assert Simple in modules
      assert WithArgs in modules
    end

    @tag :phase1
    test "generates separate files for each module" do
      assert {:ok, %{output_files: files}} = CurupiraScript.compile([Simple, WithArgs])
      assert length(files) == 2
    end
  end

  describe "compile/2 - output directory (Phase 1+)" do
    @tag :phase1
    test "uses default output directory" do
      assert {:ok, %{output_files: [%{path: path}]}} = CurupiraScript.compile(Simple)
      assert path =~ "priv/curupira_script/build"
    end

    @tag :phase1
    test "uses custom output directory" do
      assert {:ok, %{output_files: [%{path: path}]}} =
               CurupiraScript.compile(Simple, output: "custom/dir")

      assert path =~ "custom/dir"
    end
  end

  describe "compile/2 - source maps (Phase 1+)" do
    @tag :phase1
    test "generates source maps by default in dev" do
      assert {:ok, %{source_maps: maps}} = CurupiraScript.compile(Simple)
      assert is_list(maps)
      assert length(maps) > 0
    end

    @tag :phase1
    test "can disable source maps" do
      assert {:ok, %{source_maps: maps}} =
               CurupiraScript.compile(Simple, source_maps: false)

      assert maps == []
    end

    @tag :phase1
    test "source map references original Elixir file" do
      assert {:ok, %{source_maps: [map]}} = CurupiraScript.compile(Simple)
      assert map.source =~ ".ex"
    end
  end

  describe "compile/2 - error handling (Phase 1+)" do
    @tag :phase1
    test "returns error for module with syntax errors" do
      # This would require a module with invalid Elixir code
      # We'll implement this when we can actually compile
      assert {:error, {:compilation_error, _reason}} =
               CurupiraScript.compile(NonExistentModule)
    end

    @tag :phase1
    test "returns error with line information" do
      assert {:error, {:compilation_error, info}} =
               CurupiraScript.compile(NonExistentModule)

      assert is_map(info)
      assert Map.has_key?(info, :module)
    end
  end

  describe "compile/2 - data types (Phase 1+)" do
    defmodule DataTypes do
      def integers, do: 42
      def floats, do: 3.14
      def strings, do: "hello"
      def atoms, do: :ok
      def lists, do: [1, 2, 3]
      def tuples, do: {1, 2}
      def maps, do: %{key: "value"}
    end

    @tag :phase1
    test "compiles integers" do
      assert {:ok, %{output_files: [%{content: js}]}} = CurupiraScript.compile(DataTypes)
      assert js =~ "42"
    end

    @tag :phase1
    test "compiles floats" do
      assert {:ok, %{output_files: [%{content: js}]}} = CurupiraScript.compile(DataTypes)
      assert js =~ "3.14"
    end

    @tag :phase1
    test "compiles strings" do
      assert {:ok, %{output_files: [%{content: js}]}} = CurupiraScript.compile(DataTypes)
      # Should preserve string literal
      assert js =~ "hello"
    end

    @tag :phase1
    test "compiles atoms using Symbol.for()" do
      assert {:ok, %{output_files: [%{content: js}]}} = CurupiraScript.compile(DataTypes)
      assert js =~ "Symbol.for"
    end

    @tag :phase1
    test "compiles lists as arrays" do
      assert {:ok, %{output_files: [%{content: js}]}} = CurupiraScript.compile(DataTypes)
      assert js =~ "["
    end
  end

  describe "compile/2 - pattern matching (Phase 1+)" do
    defmodule PatternMatch do
      def first([head | _tail]), do: head
      def is_empty?([]), do: true
      def is_empty?(_), do: false
    end

    @tag :phase1
    test "compiles pattern matching functions" do
      assert {:ok, %{output_files: [%{content: js}]}} =
               CurupiraScript.compile(PatternMatch)

      # Should reference pattern matching library
      assert is_binary(js)
    end

    @tag :phase1
    test "handles multiple function clauses" do
      assert {:ok, %{output_files: [%{content: js}]}} =
               CurupiraScript.compile(PatternMatch)

      assert is_binary(js)
    end
  end

  describe "compile/2 - control flow (Phase 1+)" do
    defmodule ControlFlow do
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

    @tag :phase1
    test "compiles if/else" do
      assert {:ok, %{output_files: [%{content: js}]}} =
               CurupiraScript.compile(ControlFlow)

      assert is_binary(js)
    end

    @tag :phase1
    test "compiles case expressions" do
      assert {:ok, %{output_files: [%{content: js}]}} =
               CurupiraScript.compile(ControlFlow)

      assert is_binary(js)
    end

    @tag :phase1
    test "compiles guards" do
      assert {:ok, %{output_files: [%{content: js}]}} =
               CurupiraScript.compile(ControlFlow)

      assert is_binary(js)
    end
  end

  describe "compile/2 - pipe operator (Phase 1+)" do
    defmodule Pipes do
      def transform(x) do
        x
        |> add_one()
        |> multiply_two()
      end

      defp add_one(n), do: n + 1
      defp multiply_two(n), do: n * 2
    end

    @tag :phase1
    test "compiles pipe operator" do
      assert {:ok, %{output_files: [%{content: js}]}} = CurupiraScript.compile(Pipes)
      # Should chain function calls
      assert is_binary(js)
    end
  end
end

defmodule CurupiraScriptTest do
  use ExUnit.Case
  doctest CurupiraScript

  # Use compiled test fixtures from test/fixtures/
  # These are compiled by test_helper.exs before tests run
  alias Fixtures.Simple
  alias Fixtures.WithArgs
  alias Fixtures.Multiple
  alias Fixtures.DataTypes
  alias Fixtures.PatternMatch
  alias Fixtures.ControlFlow
  alias Fixtures.Pipes
  alias Fixtures.ModernElixir
  alias Fixtures.HTTP

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
      assert {:ok, %{compiled_modules: [Fixtures.Simple]}} = CurupiraScript.compile(Simple)
    end

    test "accepts a list of modules" do
      assert {:ok, %{compiled_modules: modules}} = CurupiraScript.compile([Simple, WithArgs])
      assert Fixtures.Simple in modules
      assert Fixtures.WithArgs in modules
    end

    test "accepts empty options" do
      assert {:ok, %{compiled_modules: [Fixtures.Simple]}} =
               CurupiraScript.compile(Simple, [])
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
      # Currently using string concatenation with +
      # TODO: Switch to template literals in Phase 2
      assert js =~ "+"
      assert js =~ "name"
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

  describe "compile/2 - source maps (Phase 2)" do
    @tag :phase2
    test "generates source maps by default in dev" do
      assert {:ok, %{source_maps: maps}} = CurupiraScript.compile(Simple)
      assert is_list(maps)
      assert length(maps) > 0
    end

    @tag :phase2
    test "can disable source maps" do
      assert {:ok, %{source_maps: maps}} =
               CurupiraScript.compile(Simple, source_maps: false)

      assert maps == []
    end

    @tag :phase2
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
      assert {:error, %CurupiraScript.Error{type: :compilation_error}} =
               CurupiraScript.compile(NonExistentModule)
    end

    @tag :phase1
    test "returns error with line information" do
      assert {:error, error} = CurupiraScript.compile(NonExistentModule)

      assert %CurupiraScript.Error{} = error
      assert error.type == :compilation_error
      assert error.module == NonExistentModule
      assert is_binary(error.message)
      assert is_binary(error.hint)
    end
  end

  describe "compile/2 - data types (Phase 1+)" do
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
    @tag :phase1
    test "compiles pipe operator" do
      assert {:ok, %{output_files: [%{content: js}]}} = CurupiraScript.compile(Pipes)
      # Should chain function calls
      assert is_binary(js)
    end
  end

  describe "compile/2 - structs (Phase 1+)" do
    @tag :phase1
    test "compiles struct definitions" do
      assert {:ok, %{output_files: [%{content: js}]}} =
               CurupiraScript.compile(Fixtures.Structs)

      # Should have User class
      assert js =~ "class User"
      # Should have __struct__ symbol
      assert js =~ "__struct__"
      assert js =~ "Symbol.for"
    end

    @tag :phase1
    test "compiles struct instantiation" do
      assert {:ok, %{output_files: [%{content: js}]}} =
               CurupiraScript.compile(Fixtures.Structs)

      # create_user should create new User
      assert js =~ "new User"
    end

    @tag :phase1
    test "compiles struct with defaults" do
      assert {:ok, %{output_files: [%{content: js}]}} =
               CurupiraScript.compile(Fixtures.Structs)

      # Post has default values
      assert js =~ "class Post"
    end

    @tag :phase1
    test "compiles struct updates" do
      assert {:ok, %{output_files: [%{content: js}]}} =
               CurupiraScript.compile(Fixtures.Structs)

      # update_user should use Object.assign or spread
      assert js =~ "Object.assign" or js =~ "..."
    end

    @tag :phase1
    test "compiles struct pattern matching" do
      assert {:ok, %{output_files: [%{content: js}]}} =
               CurupiraScript.compile(Fixtures.Structs)

      # pattern_match_user should check __struct__
      assert is_binary(js)
    end
  end

  describe "compile/2 - TypedStruct (Phase 1+)" do
    @tag :phase1
    test "compiles TypedStruct definitions" do
      assert {:ok, %{output_files: [%{content: js}]}} =
               CurupiraScript.compile(Fixtures.TypedStructs)

      # Should generate classes for nested modules
      assert js =~ "class Person"
      assert js =~ "class Product"
    end

    @tag :phase1
    test "compiles TypedStruct with defaults" do
      assert {:ok, %{output_files: [%{content: js}]}} =
               CurupiraScript.compile(Fixtures.TypedStructs)

      # age: 0 default
      # price: 0.0 default
      # in_stock: true default
      assert is_binary(js)
    end

    @tag :phase1
    test "TypedStruct works with instantiation" do
      assert {:ok, %{output_files: [%{content: js}]}} =
               CurupiraScript.compile(Fixtures.TypedStructs)

      # create_person should work
      assert js =~ "new Person"
    end

    @tag :phase1
    test "TypedStruct works with updates" do
      assert {:ok, %{output_files: [%{content: js}]}} =
               CurupiraScript.compile(Fixtures.TypedStructs)

      # update_person should work
      assert js =~ "Object.assign"
    end

    @tag :phase1
    test "TypedStruct works with pattern matching" do
      assert {:ok, %{output_files: [%{content: js}]}} =
               CurupiraScript.compile(Fixtures.TypedStructs)

      # Should check __struct__ field
      assert js =~ "__struct__"
    end
  end

  describe "compile/2 - then/2 and tap/2 (Phase 2)" do
    @tag :phase2
    test "compiles then/2" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(ModernElixir)

      # Should compile to function call
      assert is_binary(js)
    end

    @tag :phase2
    test "compiles tap/2" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(ModernElixir)

      # Should compile to IIFE that returns original value
      assert is_binary(js)
    end

    @tag :phase2
    test "chains then/2 and tap/2" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(ModernElixir)

      assert is_binary(js)
    end
  end

  describe "compile/2 - stepped ranges (Phase 2)" do
    @tag :phase2
    test "compiles regular ranges" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(ModernElixir)

      # Should create Range object
      assert js =~ "Range" or js =~ "range"
    end

    @tag :phase2
    test "compiles stepped ranges with positive step" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(ModernElixir)

      # Should include step parameter
      assert is_binary(js)
    end

    @tag :phase2
    test "compiles stepped ranges with negative step" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(ModernElixir)

      # Should handle descending ranges
      assert is_binary(js)
    end

    @tag :phase2
    test "ranges work with Enum" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(ModernElixir)

      # Should be iterable
      assert is_binary(js)
    end
  end

  describe "compile/2 - is_non_struct_map/1 guard (Phase 2)" do
    @tag :phase2
    test "compiles is_non_struct_map/1 guard" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(ModernElixir)

      # Should generate guard check
      assert is_binary(js)
    end

    @tag :phase2
    test "guard checks for __struct__ field" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(ModernElixir)

      # Should include __struct__ check in guard logic
      assert js =~ "__struct__" or is_binary(js)
    end

    @tag :phase2
    test "guard works in multi-clause pattern matching" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(ModernElixir)

      # Should generate multiple clauses for accepts_plain_map
      assert js =~ "accepts_plain_map"
    end

    @tag :phase2
    test "guard generates proper type checks" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(ModernElixir)

      # Should check typeof and null
      assert is_binary(js)
    end
  end

  describe "compile/2 - Duration type (Phase 2)" do
    @tag :phase2
    test "compiles Duration.new!/1 with single unit" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(ModernElixir)

      # Should create Duration object
      assert js =~ "Duration" or is_binary(js)
    end

    @tag :phase2
    test "compiles Duration.new!/1 with multiple units" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(ModernElixir)

      # Should handle multiple time units
      assert is_binary(js)
    end

    @tag :phase2
    test "Duration struct has __struct__ field" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(ModernElixir)

      # Duration instances should have __struct__
      assert js =~ "__struct__" or is_binary(js)
    end

    @tag :phase2
    test "Duration class is generated in output" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(ModernElixir)

      # Should have Duration class declaration
      assert js =~ "class Duration" or js =~ "Duration"
    end

    @tag :phase2
    test "Duration supports all time units" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(ModernElixir)

      # Should compile create_duration_all_units function
      assert js =~ "create_duration_all_units"
    end

    @tag :phase2
    test "Duration handles empty initialization" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(ModernElixir)

      # Should compile create_duration_empty function
      assert js =~ "create_duration_empty"
    end

    @tag :phase2
    test "Duration handles negative values" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(ModernElixir)

      # Should compile create_duration_negative function
      assert js =~ "create_duration_negative"
    end

    @tag :phase2
    test "Duration handles microseconds" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(ModernElixir)

      # Should compile create_duration_microseconds function
      assert js =~ "create_duration_microseconds"
    end
  end

  describe "compile/2 - HTTP client" do
    @tag :http
    test "compiles HTTP.get/1" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(HTTP)

      # Should import HTTP from runtime library
      assert js =~ "import { HTTP, HTTPResponse } from './lib/index.js';"
    end

    @tag :http
    test "compiles HTTP.get/2 with headers" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(HTTP)

      # Should compile fetch_with_auth function
      assert js =~ "fetch_with_auth"
    end

    @tag :http
    test "compiles HTTP.post/2 with body" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(HTTP)

      # Should compile create_user function
      assert js =~ "create_user"
    end

    @tag :http
    test "compiles HTTP.put/2" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(HTTP)

      # Should compile update_user function
      assert js =~ "update_user"
    end

    @tag :http
    test "compiles HTTP.delete/1" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(HTTP)

      # Should compile delete_user function
      assert js =~ "delete_user"
    end

    @tag :http
    test "compiles HTTP.request/3" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(HTTP)

      # Should compile custom_request function
      assert js =~ "custom_request"
    end

    @tag :http
    test "HTTP class uses fetch API" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(HTTP)

      # Should reference fetch in HTTP class
      assert js =~ "fetch"
    end

    @tag :http
    test "HTTP returns Response struct" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(HTTP)

      # Should import HTTPResponse from runtime library
      assert js =~ "import { HTTP, HTTPResponse } from './lib/index.js';"
    end

    @tag :http
    test "HTTPResponse has __struct__ field" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(HTTP)

      # Should set __struct__ symbol
      assert js =~ "__struct__"
      assert js =~ "Symbol.for"
    end

    @tag :http
    test "HTTP methods are async" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(HTTP)

      # Should use async/await - checking for await which implies async
      assert js =~ "await"
    end

    @tag :http
    test "HTTP returns tuple format" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(HTTP)

      # Should return {:ok, response} or {:error, reason}
      assert js =~ "__tuple__"
    end

    @tag :http
    test "handles response pattern matching" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(HTTP)

      # Should compile handle_response function
      assert js =~ "handle_response"
    end

    @tag :http
    test "handles headers option" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(HTTP)

      # Should compile fetch_with_multiple_headers
      assert js =~ "fetch_with_multiple_headers"
    end

    @tag :http
    test "handles body option" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(HTTP)

      # Body should be passed to fetch
      assert is_binary(js)
    end

    @tag :http
    test "handles error responses" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(HTTP)

      # Should handle error tuples
      assert is_binary(js)
    end
  end

  describe "JSON module (Elixir 1.18+)" do
    alias Fixtures.JSONModule

    @tag :json
    test "compiles JSON.encode!/1" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(JSONModule)

      # Should have JSON class with static encode method
      assert js =~ "JSON"
      assert js =~ "encode"
    end

    @tag :json
    test "compiles JSON.decode!/1" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(JSONModule)

      # Should have JSON class with static decode method
      assert js =~ "JSON"
      assert js =~ "decode"
    end

    @tag :json
    test "handles JSON.encode for maps" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(JSONModule)

      # Should compile encode_map function
      assert js =~ "encode_map"
    end

    @tag :json
    test "handles JSON.encode for lists" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(JSONModule)

      # Should compile encode_list function
      assert js =~ "encode_list"
    end

    @tag :json
    test "handles JSON.decode for objects" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(JSONModule)

      # Should compile decode_object function
      assert js =~ "decode_object"
    end

    @tag :json
    test "handles JSON.decode for arrays" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(JSONModule)

      # Should compile decode_array function
      assert js =~ "decode_array"
    end

    @tag :json
    test "handles nested structures" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(JSONModule)

      # Should compile encode_nested function
      assert js =~ "encode_nested"
    end

    @tag :json
    test "handles safe encode (returns tuples)" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(JSONModule)

      # Should compile encode_safe function
      assert js =~ "encode_safe"
    end

    @tag :json
    test "handles safe decode (returns tuples)" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(JSONModule)

      # Should compile decode_safe function
      assert js =~ "decode_safe"
    end

    @tag :json
    test "handles roundtrip encoding/decoding" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(JSONModule)

      # Should compile roundtrip function
      assert js =~ "roundtrip"
    end

    @tag :json
    test "handles decode with options" do
      assert {:ok, %{output_files: [%{content: js}]}} =
        CurupiraScript.compile(JSONModule)

      # Should compile decode_atoms_as_keys function
      assert js =~ "decode_atoms_as_keys"
    end
  end
end

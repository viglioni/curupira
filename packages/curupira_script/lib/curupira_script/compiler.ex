defmodule CurupiraScript.Compiler do
  @moduledoc """
  The entry point for CurupiraScript compilation.

  Takes Elixir module(s) and compiles them to JavaScript (ES2020+).

  ## Example

      iex> CurupiraScript.Compiler.compile(MyApp)
      {:ok, %{
        compiled_modules: [MyApp],
        output_files: [%{path: "priv/curupira_script/build/Elixir.MyApp.js", content: "..."}],
        source_maps: []
      }}

  """

  alias CurupiraScript.{Beam, Translator}
  alias ESTree.Tools.{Builder, Generator}

  @doc """
  Compile one or more Elixir modules to JavaScript.

  ## Parameters

  - `modules` - Single module atom or list of module atoms
  - `opts` - Keyword list of options

  ## Options

  - `:output` - Output directory (default: "priv/curupira_script/build")
  - `:source_maps` - Generate source maps (default: true in dev, false in prod)
  - `:format` - Output format, only `:es` supported (default: `:es`)

  ## Returns

  - `{:ok, map}` - Success with compilation result
  - `{:error, term}` - Compilation error

  """
  @spec compile(module() | [module()], keyword()) :: {:ok, map()} | {:error, term()}
  def compile(modules, opts \\ [])

  def compile(module, opts) when is_atom(module) do
    compile([module], opts)
  end

  def compile(modules, opts) when is_list(modules) do
    # Validate input
    case validate_input(modules, opts) do
      :ok ->
        do_compile(modules, opts)

      error ->
        error
    end
  end

  # Private functions

  defp validate_input([], _opts) do
    {:error, :empty_module_list}
  end

  defp validate_input(modules, opts) when is_list(modules) do
    # Check all items are atoms
    case Enum.find(modules, fn x -> not is_atom(x) end) do
      nil ->
        validate_options(opts)

      invalid ->
        {:error, {:invalid_module, invalid}}
    end
  end

  defp validate_options(opts) do
    # For now, accept any options - we'll validate specific ones as we implement them
    # TODO: Phase 0 - implement full option validation
    _ = opts
    :ok
  end

  defp do_compile(modules, opts) do
    output_dir = Keyword.get(opts, :output, "priv/curupira_script/build")
    source_maps = Keyword.get(opts, :source_maps, Mix.env() == :dev)

    # Extract AST from all modules
    case extract_module_info(modules) do
      {:ok, module_infos} ->
        # Translate each module to JavaScript
        case translate_modules(module_infos) do
          {:ok, js_modules} ->
            # Build output files
            output_files = build_output_files(js_modules, output_dir)

            {:ok,
             %{
               compiled_modules: modules,
               output_files: output_files,
               source_maps: if(source_maps, do: [], else: [])
             }}

          error ->
            error
        end

      error ->
        error
    end
  end

  defp extract_module_info(modules) do
    results =
      Enum.map(modules, fn module ->
        case Beam.debug_info(module) do
          {:ok, info} ->
            {:ok, {module, info}}

          {:error, reason} ->
            {:error, {:compilation_error, %{module: module, reason: reason}}}
        end
      end)

    # Check if any errors occurred
    case Enum.find(results, fn
           {:error, _} -> true
           _ -> false
         end) do
      nil ->
        module_infos =
          Enum.map(results, fn {:ok, module_info} -> module_info end)

        {:ok, module_infos}

      error ->
        error
    end
  end

  defp translate_modules(module_infos) do
    results =
      Enum.map(module_infos, fn {module, info} ->
        case translate_module(module, info) do
          {:ok, js_ast} ->
            # Convert AST to JavaScript code
            js_code = Generator.generate(js_ast)
            {:ok, {module, js_code}}

          error ->
            error
        end
      end)

    # Check if any errors occurred
    case Enum.find(results, fn
           {:error, _} -> true
           _ -> false
         end) do
      nil ->
        js_modules = Enum.map(results, fn {:ok, module_js} -> module_js end)
        {:ok, js_modules}

      error ->
        error
    end
  end

  defp translate_module(_module, info) do
    # For now, generate a simple ES module
    # TODO: Implement full translation in translate/* modules

    # Get module functions
    definitions = Map.get(info, :definitions, [])

    # Translate each function
    functions = translate_functions(definitions)

    # Build ES module: export default { ...functions }
    module_ast =
      Builder.export_default_declaration(
        Builder.object_expression(functions)
      )

    {:ok, Builder.program([module_ast])}
  end

  defp translate_functions(definitions) do
    Enum.flat_map(definitions, fn
      # Public function
      {{name, _arity}, :def, _meta, clauses} ->
        # For now, only handle single-clause functions
        # TODO: Handle multi-clause functions with pattern matching
        [{_clause_meta, params, _guards, body}] = clauses

        # Translate function parameters
        js_params = translate_params(params)

        # Translate function body
        js_body_expr = Translator.translate(body)

        # Wrap in block statement with return
        js_body =
          Builder.block_statement([
            Builder.return_statement(js_body_expr)
          ])

        [
          Builder.property(
            Builder.identifier(Atom.to_string(name)),
            Builder.function_expression(js_params, [], js_body)
          )
        ]

      # Skip private functions, macros, etc for now
      _ ->
        []
    end)
  end

  defp translate_params(params) do
    Enum.map(params, fn
      {name, _meta, nil} when is_atom(name) ->
        Builder.identifier(Atom.to_string(name))

      # TODO: Handle pattern matching in parameters
      other ->
        IO.warn("Unsupported parameter pattern: #{inspect(other)}")
        Builder.identifier("_")
    end)
  end

  defp build_output_files(js_modules, output_dir) do
    Enum.map(js_modules, fn {module, js_code} ->
      filename = "Elixir.#{module}.js"
      path = Path.join(output_dir, filename)

      %{
        path: path,
        content: js_code
      }
    end)
  end
end

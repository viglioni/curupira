defmodule CurupiraScript.DependencyWalker do
  @moduledoc """
  Walks the dependency tree starting from entry modules.

  Detects which modules are called by the entry modules and recursively
  includes them in the compilation set.
  """

  alias CurupiraScript.Beam

  @doc """
  Find all modules that need to be compiled starting from entry modules.

  Returns a MapSet of all modules (entry + dependencies).
  """
  @spec walk([module()]) :: {:ok, MapSet.t(module())} | {:error, term()}
  def walk(entry_modules) when is_list(entry_modules) do
    # Start with entry modules
    initial = MapSet.new(entry_modules)

    # Recursively walk dependencies
    walk_recursive(initial, initial)
  end

  defp walk_recursive(to_process, already_seen) do
    if MapSet.size(to_process) == 0 do
      {:ok, already_seen}
    else
      # Take one module to process
      module = to_process |> Enum.take(1) |> List.first()
      remaining = MapSet.delete(to_process, module)

      # Get its dependencies
      case get_module_dependencies(module) do
        {:ok, deps} ->
          # Filter out already seen and stdlib modules
          new_deps =
            deps
            |> MapSet.new()
            |> MapSet.difference(already_seen)
            |> filter_stdlib_modules()

          # Add new dependencies to processing queue and seen set
          new_to_process = MapSet.union(remaining, new_deps)
          new_seen = MapSet.union(already_seen, new_deps)

          walk_recursive(new_to_process, new_seen)

        {:error, reason} ->
          {:error, {:dependency_error, module, reason}}
      end
    end
  end

  defp get_module_dependencies(module) do
    # Get BEAM debug info
    case Beam.debug_info(module) do
      {:ok, info} ->
        # Extract function definitions
        definitions = Map.get(info, :definitions, [])

        # Find all remote module calls
        deps = extract_remote_calls(definitions)

        {:ok, deps}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_remote_calls(definitions) do
    Enum.reduce(definitions, MapSet.new(), fn
      {{_name, _arity}, :def, _meta, clauses}, acc ->
        Enum.reduce(clauses, acc, fn {_clause_meta, _params, _guards, body}, acc2 ->
          find_remote_calls_in_expr(body, acc2)
        end)

      _, acc ->
        acc
    end)
  end

  defp find_remote_calls_in_expr(expr, modules) do
    case expr do
      # Remote call: Module.function(...)
      # Expanded form with atom
      {{:., _, [module, _func]}, _, args} when is_atom(module) and is_list(args) ->
        modules
        |> MapSet.put(module)
        |> then(fn acc -> safe_reduce(args, acc) end)

      # Unexpanded form with __aliases__
      {{:., _, [{:__aliases__, _, parts}, _func]}, _, args} when is_list(args) ->
        # Reconstruct module name: [:MyApp, :Site] -> MyApp.Site
        module = Module.concat(parts)
        modules
        |> MapSet.put(module)
        |> then(fn acc -> safe_reduce(args, acc) end)

      # Struct reference: %Module{...}
      {:%, _, [module, {:%{}, _, _fields}]} when is_atom(module) ->
        MapSet.put(modules, module)

      {:%, _, [{:__aliases__, _, parts}, {:%{}, _, _fields}]} ->
        module = Module.concat(parts)
        MapSet.put(modules, module)

      # List - recurse
      list when is_list(list) ->
        safe_reduce(list, modules)

      # Tuple - recurse
      tuple when is_tuple(tuple) ->
        tuple
        |> Tuple.to_list()
        |> safe_reduce(modules)

      # Leaf nodes
      _ ->
        modules
    end
  end

  defp safe_reduce(list, modules) when is_list(list) do
    Enum.reduce(list, modules, fn elem, acc ->
      find_remote_calls_in_expr(elem, acc)
    end)
  end

  defp filter_stdlib_modules(modules) do
    # Filter out Elixir stdlib and Erlang modules
    MapSet.filter(modules, fn module ->
      module_str = Atom.to_string(module)

      # Keep user modules (start with Elixir but not stdlib)
      cond do
        # Erlang modules (lowercase)
        module_str =~ ~r/^[a-z]/ -> false

        # Elixir stdlib (common ones)
        module in [Enum, String, Map, List, Kernel, Module, Code, File, IO, System] -> false
        String.starts_with?(module_str, "Elixir.Enum") -> false
        String.starts_with?(module_str, "Elixir.String") -> false
        String.starts_with?(module_str, "Elixir.Map") -> false
        String.starts_with?(module_str, "Elixir.List") -> false
        String.starts_with?(module_str, "Elixir.Kernel") -> false

        # Keep everything else
        true -> true
      end
    end)
  end
end

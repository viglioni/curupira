defmodule CurupiraJS.Bundler do
  @moduledoc """
  Bundles multiple compiled modules into a single JavaScript file.

  Creates a single bundle with all modules exported as a default object.
  """

  @doc """
  Bundle compiled modules into a single JavaScript file.

  ## Parameters
  - `modules` - List of {module, js_code} tuples
  - `opts` - Options (reserved for future use)

  ## Returns
  - `{:ok, bundled_js_code}`
  """
  @spec bundle([{module(), String.t()}], keyword()) :: {:ok, String.t()}
  def bundle(modules, _opts \\ []) when is_list(modules) do
    # Detect which runtime imports are needed across all modules
    runtime_imports = detect_runtime_imports(modules)

    # Generate import statement
    import_statement = generate_import_statement(runtime_imports)

    # Generate module exports
    module_exports = generate_module_exports(modules)

    # Combine into single file
    bundled_code = """
    #{import_statement}

    #{module_exports}
    """

    {:ok, bundled_code}
  end

  defp detect_runtime_imports(modules) do
    # Check which runtime modules are imported in any of the JS files
    imports = MapSet.new()

    Enum.reduce(modules, imports, fn {_module, js_code}, acc ->
      cond do
        String.contains?(js_code, "import { HTTP") -> MapSet.put(acc, :http)
        String.contains?(js_code, "import { JSON") -> MapSet.put(acc, :json)
        String.contains?(js_code, "import { Enum") -> MapSet.put(acc, :enum)
        String.contains?(js_code, "import {") and String.contains?(js_code, "String") -> MapSet.put(acc, :string)
        String.contains?(js_code, "import {") and String.contains?(js_code, "Map") -> MapSet.put(acc, :map)
        true -> acc
      end
    end)
  end

  defp generate_import_statement(runtime_imports) do
    if MapSet.size(runtime_imports) > 0 do
      # Collect specifiers
      specifiers = []

      specifiers = if MapSet.member?(runtime_imports, :enum) do
        ["Enum" | specifiers]
      else
        specifiers
      end

      specifiers = if MapSet.member?(runtime_imports, :string) do
        ["ElixirString as String" | specifiers]
      else
        specifiers
      end

      specifiers = if MapSet.member?(runtime_imports, :map) do
        ["ElixirMap as Map" | specifiers]
      else
        specifiers
      end

      specifiers = if MapSet.member?(runtime_imports, :json) do
        ["JSON" | specifiers]
      else
        specifiers
      end

      specifiers = if MapSet.member?(runtime_imports, :http) do
        ["HTTP", "HTTPResponse" | specifiers]
      else
        specifiers
      end

      "import { #{Enum.reverse(specifiers) |> Enum.join(", ")} } from './lib/index.js';"
    else
      "// No runtime imports needed"
    end
  end

  defp generate_module_exports(modules) do
    # Build nested structure: MyApp.Site.Module -> {MyApp: {Site: {Module: {...}}}}
    nested_tree = build_nested_tree(modules)

    # If there's only one top-level key, unwrap it for cleaner access
    # So {Fixtures: {Simple: {}, WithArgs: {}}} becomes {Simple: {}, WithArgs: {}}
    unwrapped_tree = case Map.keys(nested_tree) do
      [single_key] -> Map.get(nested_tree, single_key)
      _ -> nested_tree
    end

    # Convert to JavaScript
    js_tree = tree_to_js(unwrapped_tree, 0)

    """
    export default #{js_tree};
    """
  end

  defp build_nested_tree(modules) do
    # Build a nested map structure
    Enum.reduce(modules, %{}, fn {module, js_code}, tree ->
      # Strip "Elixir." prefix and split into parts
      parts =
        module
        |> strip_elixir_prefix()
        |> String.split(".")

      # Extract module content
      content = extract_module_content(js_code)

      # Insert into tree
      put_in_tree(tree, parts, content)
    end)
  end

  defp put_in_tree(tree, [part], content) do
    # Last part - store the module content
    Map.put(tree, part, {:module, content})
  end

  defp put_in_tree(tree, [part | rest], content) do
    # Intermediate part - recurse
    subtree = Map.get(tree, part, %{})
    Map.put(tree, part, put_in_tree(subtree, rest, content))
  end

  defp tree_to_js(tree, indent_level) do
    indent = String.duplicate("  ", indent_level)
    inner_indent = String.duplicate("  ", indent_level + 1)

    entries =
      Enum.map(tree, fn
        {key, {:module, content}} ->
          # Module content - paste directly
          "#{inner_indent}#{key}: #{content}"

        {key, subtree} when is_map(subtree) ->
          # Nested namespace
          nested_js = tree_to_js(subtree, indent_level + 1)
          "#{inner_indent}#{key}: #{nested_js}"
      end)

    "{\n#{Enum.join(entries, ",\n")}\n#{indent}}"
  end

  defp strip_elixir_prefix(module) do
    module
    |> Atom.to_string()
    |> String.replace_prefix("Elixir.", "")
  end

  defp extract_module_content(js_code) do
    # Parse the JS code to extract the object from "export default { ... }"
    # For now, simple string manipulation (could use a proper JS parser later)

    # Remove import statements
    without_imports = js_code
    |> String.split("\n")
    |> Enum.reject(&String.starts_with?(&1, "import "))
    |> Enum.reject(&String.starts_with?(&1, "class "))  # Remove class definitions (they'll be in runtime)
    |> Enum.join("\n")

    # Find "export default" and extract content
    case Regex.run(~r/export default\s+(\{[\s\S]*\});?\s*$/m, without_imports) do
      [_full, content] ->
        content

      nil ->
        # Fallback: return the whole code
        "{}"
    end
  end
end

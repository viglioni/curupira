defmodule CurupiraScript.Bundler do
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
    # Extract module code without import statements
    module_objects = Enum.map(modules, fn {module, js_code} ->
      # Strip "Elixir." prefix from module name
      module_name = strip_elixir_prefix(module)

      # Extract the export default { ... } content
      module_content = extract_module_content(js_code)

      # Generate: "Module.Name": { ...functions... }
      ~s("#{module_name}": #{module_content})
    end)

    # Combine all modules into single export
    """
    export default {
      #{Enum.join(module_objects, ",\n  ")}
    };
    """
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

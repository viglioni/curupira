defmodule Mix.Tasks.CurupiraScript.Build do
  use Mix.Task

  @shortdoc "Builds JavaScript bundle from Elixir modules"

  @moduledoc """
  Compiles Elixir modules to JavaScript and bundles them into a single file.

  ## Configuration

  In your `mix.exs`:

      def project do
        [
          curupira_js: [
            input: [MyApp.Site, MyApp.Helper],  # Entry modules
            output: "js/elixir_bundle.js"       # Output path (default)
          ]
        ]
      end

  ## Usage

      $ mix curupira_script.build

  This will:
  1. Find all dependencies of the entry modules
  2. Compile them to JavaScript
  3. Bundle into a single file
  4. Write to the output path
  """

  alias CurupiraScript.{DependencyWalker, Compiler, Bundler}

  @impl Mix.Task
  def run(_args) do
    # Get configuration
    config = Mix.Project.config()[:curupira_js] || []

    entry_modules = Keyword.get(config, :input, [])
    output_path = Keyword.get(config, :output, "js/elixir_bundle.js")

    if entry_modules == [] do
      Mix.raise("""
      No entry modules configured!

      Add to your mix.exs:

        def project do
          [
            curupira_js: [
              input: [MyApp.Site],
              output: "js/elixir_bundle.js"
            ]
          ]
        end
      """)
    end

    Mix.shell().info("Building JavaScript bundle...")
    Mix.shell().info("Entry modules: #{inspect(entry_modules)}")

    # Step 1: Walk dependency tree
    Mix.shell().info("Walking dependency tree...")

    case DependencyWalker.walk(entry_modules) do
      {:ok, all_modules} ->
        module_count = MapSet.size(all_modules)
        Mix.shell().info("Found #{module_count} module(s) to compile")

        # Step 2: Compile all modules
        Mix.shell().info("Compiling modules...")

        modules_list = MapSet.to_list(all_modules)

        case Compiler.compile(modules_list, source_maps: false) do
          {:ok, %{output_files: files}} ->
            # Extract module code
            modules_with_code = Enum.map(files, fn %{path: path, content: js_code} ->
              # Extract module name from path: "path/Elixir.Module.Name.js" -> Module.Name
              module_name =
                path
                |> Path.basename(".js")
                |> String.replace_prefix("Elixir.", "")
                |> String.to_atom()

              {module_name, js_code}
            end)

            # Step 3: Bundle
            Mix.shell().info("Bundling modules...")

            {:ok, bundled_code} = Bundler.bundle(modules_with_code)

            # Step 4: Write to file
            Mix.shell().info("Writing bundle to #{output_path}...")

            # Ensure directory exists
            output_path |> Path.dirname() |> File.mkdir_p!()

            File.write!(output_path, bundled_code)

            Mix.shell().info([:green, "✓ Bundle created: #{output_path}"])
            Mix.shell().info("  Modules: #{module_count}")
            Mix.shell().info("  Size: #{byte_size(bundled_code)} bytes")

          {:error, error} ->
            Mix.raise("Compilation failed: #{inspect(error)}")
        end

      {:error, reason} ->
        Mix.raise("Dependency walking failed: #{inspect(reason)}")
    end
  end
end

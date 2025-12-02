defmodule Mix.Compilers.CurupiraJs do
  @moduledoc """
  Mix compiler for CurupiraJS.

  Integrates JavaScript bundle generation into the normal `mix compile` workflow.

  ## Configuration

  Add to your `mix.exs`:

      def project do
        [
          # Add :curupira_js to compilers list
          compilers: Mix.compilers() ++ [:curupira_js],

          # Configure entry modules and output
          curupira_js: [
            input: [MyApp.Site, MyApp.Helper],
            output: "js/elixir_bundle.js"
          ]
        ]
      end

  Now `mix compile` will automatically build your JavaScript bundle after compiling Elixir.

  ## Behavior

  - Only rebuilds if entry modules or their dependencies changed
  - Tracks manifest file for incremental compilation
  - Reports compilation errors properly to Mix
  """

  @manifest_vsn 1
  @manifest_file ".mix_curupira_js_manifest"

  @doc """
  Runs the CurupiraJS compiler.

  Returns:
  - `{:ok, []}` - Compilation successful, no diagnostics
  - `{:noop, []}` - Nothing to compile (up to date)
  - `{:error, [diagnostic]}` - Compilation failed with diagnostics
  """
  @spec run(keyword()) :: {:ok, []} | {:noop, []} | {:error, []}
  def run(_args) do
    config = Mix.Project.config()[:curupira_js]

    if config && config[:input] do
      # Get configuration
      entry_modules = List.wrap(config[:input])
      output_path = config[:output] || "js/elixir_bundle.js"

      # Check if we need to rebuild
      manifest = read_manifest()

      if needs_rebuild?(entry_modules, output_path, manifest) do
        case build_bundle(entry_modules, output_path) do
          :ok ->
            # Write new manifest
            write_manifest(entry_modules, output_path)
            {:ok, []}

          {:error, reason} ->
            diagnostic = %Mix.Task.Compiler.Diagnostic{
              compiler_name: "curupira_js",
              file: "mix.exs",
              position: 0,
              message: "JavaScript bundle compilation failed: #{inspect(reason)}",
              severity: :error
            }

            {:error, [diagnostic]}
        end
      else
        {:noop, []}
      end
    else
      # No configuration - skip
      {:noop, []}
    end
  end

  @doc """
  Returns paths to clean for the CurupiraJS compiler.
  """
  @spec clean() :: :ok
  def clean do
    File.rm(@manifest_file)
    :ok
  end

  @doc """
  Returns all manifests for the CurupiraJS compiler.
  """
  @spec manifests() :: [Path.t()]
  def manifests do
    [@manifest_file]
  end

  # Private functions

  defp build_bundle(entry_modules, output_path) do
    alias CurupiraJS.{DependencyWalker, Compiler, Bundler}

    # Step 1: Walk dependency tree
    case DependencyWalker.walk(entry_modules) do
      {:ok, all_modules} ->
        modules_list = MapSet.to_list(all_modules)

        # Step 2: Compile all modules
        case Compiler.compile(modules_list, source_maps: false) do
          {:ok, %{output_files: files}} ->
            # Extract module code
            modules_with_code =
              Enum.map(files, fn %{path: path, content: js_code} ->
                module_name =
                  path
                  |> Path.basename(".js")
                  |> String.replace_prefix("Elixir.", "")
                  |> String.to_atom()

                {module_name, js_code}
              end)

            # Step 3: Bundle
            {:ok, bundled_code} = Bundler.bundle(modules_with_code)

            # Step 4: Write to file
            output_path |> Path.dirname() |> File.mkdir_p!()
            File.write!(output_path, bundled_code)

            Mix.shell().info("Generated JavaScript bundle: #{output_path}")
            :ok

          {:error, error} ->
            {:error, error}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp needs_rebuild?(entry_modules, output_path, manifest) do
    cond do
      # No manifest - first build
      manifest == nil ->
        true

      # Output file doesn't exist
      not File.exists?(output_path) ->
        true

      # Configuration changed (different entry modules or output path)
      manifest.entry_modules != entry_modules or manifest.output_path != output_path ->
        true

      # Check if any module changed (compare module_info timestamps)
      modules_changed?(entry_modules, manifest) ->
        true

      # Everything up to date
      true ->
        false
    end
  end

  defp modules_changed?(entry_modules, manifest) do
    # Get all dependencies
    case CurupiraJS.DependencyWalker.walk(entry_modules) do
      {:ok, all_modules} ->
        # Check if any module was recompiled
        Enum.any?(all_modules, fn module ->
          current_timestamp = get_module_timestamp(module)
          manifest_timestamp = Map.get(manifest.module_timestamps, module)

          current_timestamp != manifest_timestamp
        end)

      {:error, _} ->
        # If we can't walk dependencies, rebuild to be safe
        true
    end
  end

  defp get_module_timestamp(module) do
    try do
      # Get the BEAM file modification time
      case :code.which(module) do
        path when is_list(path) ->
          path
          |> List.to_string()
          |> File.stat!()
          |> Map.get(:mtime)

        _ ->
          nil
      end
    rescue
      _ -> nil
    end
  end

  defp read_manifest do
    if File.exists?(@manifest_file) do
      case File.read(@manifest_file) do
        {:ok, contents} ->
          case :erlang.binary_to_term(contents) do
            {@manifest_vsn, data} -> data
            _ -> nil
          end

        _ ->
          nil
      end
    else
      nil
    end
  end

  defp write_manifest(entry_modules, output_path) do
    # Get timestamps for all modules
    {:ok, all_modules} = CurupiraJS.DependencyWalker.walk(entry_modules)

    module_timestamps =
      all_modules
      |> Enum.map(fn module -> {module, get_module_timestamp(module)} end)
      |> Map.new()

    manifest = %{
      entry_modules: entry_modules,
      output_path: output_path,
      module_timestamps: module_timestamps
    }

    File.write!(@manifest_file, :erlang.term_to_binary({@manifest_vsn, manifest}))
  end
end

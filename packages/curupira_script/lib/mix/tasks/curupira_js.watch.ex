defmodule Mix.Tasks.CurupiraJs.Watch do
  use Mix.Task

  @shortdoc "Watches Elixir files and rebuilds JavaScript bundle on changes"

  @moduledoc """
  Watches for changes in Elixir source files and automatically rebuilds the JavaScript bundle.

  ## Usage

      $ mix curupira_js.watch

  This will:
  1. Build the initial bundle
  2. Watch for changes in `.ex` files
  3. Rebuild automatically when changes are detected
  4. Continue watching until interrupted (Ctrl+C)

  ## Configuration

  Uses the same configuration as `mix curupira_js.build`:

      # mix.exs
      def project do
        [
          curupira_js: [
            input: [MyApp.Site],
            output: "js/elixir_bundle.js"
          ]
        ]
      end

  ## Watched Directories

  Monitors:
  - `lib/` - Main source directory
  - `test/fixtures/` - Test fixtures (if they exist)

  Only `.ex` files are watched (not `.exs`).
  """

  @impl Mix.Task
  def run(_args) do
    # Ensure the application is started for FileSystem
    {:ok, _} = Application.ensure_all_started(:file_system)

    Mix.shell().info("Starting CurupiraJS watch mode...")
    Mix.shell().info("Press Ctrl+C to stop")
    Mix.shell().info("")

    # Build initial bundle
    Mix.Tasks.CurupiraJs.Build.run([])

    # Start watching
    watch_directories = get_watch_directories()
    Mix.shell().info("")
    Mix.shell().info("Watching directories:")
    Enum.each(watch_directories, fn dir ->
      Mix.shell().info("  - #{dir}")
    end)
    Mix.shell().info("")

    # Start file watcher
    unless Code.ensure_loaded?(FileSystem) do
      Mix.raise("FileSystem is required for watch mode. Add {:file_system, \"~> 1.0\"} to your deps.")
    end

    {:ok, pid} = apply(FileSystem, :start_link, [[dirs: watch_directories]])
    apply(FileSystem, :subscribe, [pid])

    # Keep process alive and handle file events
    receive_loop()
  end

  defp receive_loop do
    receive do
      {_pid, {_event, path}} = _msg ->
        # Only rebuild for .ex files (not .exs)
        if Path.extname(path) == ".ex" do
          Mix.shell().info("")
          Mix.shell().info("[#{timestamp()}] Change detected: #{Path.relative_to_cwd(path)}")
          Mix.shell().info("Rebuilding...")

          # Small delay to allow multiple rapid changes to settle
          Process.sleep(100)

          # Rebuild
          try do
            Mix.Tasks.CurupiraJs.Build.run([])
          rescue
            error ->
              Mix.shell().error("Build failed: #{inspect(error)}")
          end

          Mix.shell().info("Watching for changes...")
        end

        receive_loop()

      _other ->
        receive_loop()
    end
  end

  defp get_watch_directories do
    base_dirs = ["lib"]

    # Add test/fixtures if it exists (for development)
    if File.dir?("test/fixtures") do
      base_dirs ++ ["test/fixtures"]
    else
      base_dirs
    end
  end

  defp timestamp do
    {{y, m, d}, {h, min, s}} = :calendar.local_time()
    :io_lib.format("~4..0B-~2..0B-~2..0B ~2..0B:~2..0B:~2..0B", [y, m, d, h, min, s])
    |> IO.iodata_to_binary()
  end
end

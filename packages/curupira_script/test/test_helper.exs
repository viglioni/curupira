# Ensure all dependencies are loaded
Application.ensure_all_started(:typed_struct)

# Compile test fixtures before running tests
fixtures_dir = Path.join(__DIR__, "fixtures")

if File.exists?(fixtures_dir) do
  fixtures_files =
    fixtures_dir
    |> Path.join("**/*.ex")
    |> Path.wildcard()

  unless Enum.empty?(fixtures_files) do
    case Kernel.ParallelCompiler.compile(fixtures_files) do
      {:ok, _modules, _warnings} -> :ok
      {:error, _errors, _warnings} -> :ok  # Continue even if some fixtures fail
    end
  end
end

# Exclude phase2 tests by default (source maps, advanced features)
ExUnit.start(exclude: [:phase2])

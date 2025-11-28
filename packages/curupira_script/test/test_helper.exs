# Compile test fixtures before running tests
fixtures_dir = Path.join(__DIR__, "fixtures")

if File.exists?(fixtures_dir) do
  fixtures_files =
    fixtures_dir
    |> Path.join("**/*.ex")
    |> Path.wildcard()

  unless Enum.empty?(fixtures_files) do
    {:ok, _modules, _warnings} = Kernel.ParallelCompiler.compile(fixtures_files)
  end
end

ExUnit.start()

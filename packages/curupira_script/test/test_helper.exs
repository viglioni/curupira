# Compile test fixtures before running tests
fixtures_dir = Path.join(__DIR__, "fixtures")

if File.exists?(fixtures_dir) do
  fixtures_dir
  |> Path.join("**/*.ex")
  |> Path.wildcard()
  |> Kernel.ParallelCompiler.compile()
end

ExUnit.start()

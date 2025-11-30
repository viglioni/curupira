# Compile TypedStruct fixture with dependencies loaded
Mix.start()
Mix.Task.run("loadpaths")
Application.ensure_all_started(:typed_struct)

Code.compiler_options(ignore_module_conflict: true)

# Compile to current directory
{:ok, modules, _warnings} = Kernel.ParallelCompiler.compile(
  ["test/fixtures/typed_structs.ex"],
  dest: "."
)

IO.puts("✅ Compiled TypedStruct fixture to current directory: #{inspect(modules)}")

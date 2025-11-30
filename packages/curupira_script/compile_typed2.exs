# Load TypedStruct first
Mix.start()
Mix.Task.run("loadpaths")
Application.ensure_all_started(:typed_struct)

# Set output directory
Code.compiler_options(ignore_module_conflict: true)
System.put_env("ELIXIRC_OPTS", "-o .")

# Compile
Code.compile_file("test/fixtures/typed_structs.ex", ".")

IO.puts("Done")

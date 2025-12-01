# Test FFI compilation
try do
  Code.compiler_options(ignore_module_conflict: true)
  Code.compile_file("test/fixtures/ffi_example.ex")

  alias CurupiraJS.Compiler

  case Compiler.compile(Fixtures.FFIExample, source_maps: false) do
    {:ok, result} ->
      js_code = hd(result.output_files).content
      IO.puts("=== FFI Compilation Success ===")
      IO.puts(js_code)

    {:error, error} ->
      IO.puts("=== FFI Compilation Failed ===")
      IO.inspect(error, pretty: true, limit: :infinity)
  end
rescue
  e ->
    IO.puts("=== Exception ===")
    IO.inspect(e, pretty: true, limit: :infinity)
    IO.puts(Exception.format(:error, e, __STACKTRACE__))
end

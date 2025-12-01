# Simple FFI verification - shows generated JavaScript
# Run with: mix run verify_ffi.exs

# Compile the FFI example
Code.compiler_options(ignore_module_conflict: true)
Code.compile_file("test/fixtures/ffi_example.ex")

alias CurupiraJS.Compiler

IO.puts("\n=== Compiling FFI Example ===\n")

case Compiler.compile(Fixtures.FFIExample, source_maps: false) do
  {:ok, result} ->
    js_code = hd(result.output_files).content

    IO.puts("✓ Compilation successful!")
    IO.puts("\n=== Generated JavaScript ===\n")
    IO.puts(js_code)
    IO.puts("\n=== End ===\n")

    # Check for expected patterns
    checks = [
      {"Math.random", "External JS path (Math.random)"},
      {"(a, b) => a + b", "Inline JS function"},
      {"Symbol.for(\"ok\")", "OK atom representation"},
      {"_result.ok", "Result type checking"},
      {"Symbol.for(\"error\")", "Error atom representation"}
    ]

    IO.puts("\n=== Verification ===\n")

    Enum.each(checks, fn {pattern, description} ->
      if String.contains?(js_code, pattern) do
        IO.puts("✓ #{description}")
      else
        IO.puts("✗ #{description} - NOT FOUND")
      end
    end)

  {:error, error} ->
    IO.puts("✗ Compilation failed:")
    IO.inspect(error, pretty: true)
end

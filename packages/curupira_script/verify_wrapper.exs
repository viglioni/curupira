# Verify FFI wrapper support
Code.compiler_options(ignore_module_conflict: true)
Code.compile_file("test/fixtures/ffi_wrapped.ex")

alias CurupiraJS.Compiler

IO.puts("\n=== Compiling FFI Wrapper Example ===\n")

case Compiler.compile(Fixtures.FFIWrapped, source_maps: false) do
  {:ok, result} ->
    js_code = hd(result.output_files).content

    IO.puts("✓ Compilation successful!")
    IO.puts("\n=== Generated JavaScript ===\n")
    IO.puts(js_code)
    IO.puts("\n=== End ===\n")

    # Check for expected patterns
    checks = [
      {"create_context:", "create_context function"},
      {"set_fill_style:", "set_fill_style function"},
      {"fill_rect:", "fill_rect function"},
      {"get_width:", "get_width function"},
      {"try_get_context:", "try_get_context function"},
      {"return", "Return statements present"}
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
    IO.inspect(error, pretty: true, limit: :infinity)
end

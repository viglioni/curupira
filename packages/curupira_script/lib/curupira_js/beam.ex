defmodule CurupiraJS.Beam do
  @moduledoc """
  Extracts macro-expanded AST from BEAM files.

  Uses Erlang's debug_info feature (available in Erlang 20+) to extract
  the Elixir AST with all macros already expanded. This means we don't have
  to handle macro expansion ourselves.

  ## Example

      iex> CurupiraJS.Beam.debug_info(MyModule)
      {:ok, %{module: MyModule, definitions: [...], file: "lib/my_module.ex", ...}}

  """

  @doc """
  Extracts the macro-expanded AST from a module's BEAM file.

  ## Parameters

  - `module` - Module atom or binary BEAM data

  ## Returns

  - `{:ok, map}` - Module info with AST
  - `{:ok, atom, map, list}` - For protocols (protocol name, info, implementations)
  - `{:error, binary}` - Error message

  ## Module Info Map

  The returned map contains:
  - `:module` - Module name
  - `:file` - Source file path
  - `:line` - Line number
  - `:definitions` - List of function definitions
  - `:attributes` - Module attributes
  - `:compile_opts` - Compilation options
  - `:deprecated` - Deprecated functions
  - `:unreachable` - Unreachable functions
  - `:beam_path` - Path to BEAM file
  - `:last_modified` - Last modified timestamp

  """
  @spec debug_info(module() | binary()) ::
          {:ok, map()} | {:ok, atom(), map(), list()} | {:error, binary()}
  def debug_info(module) when is_atom(module) do
    do_debug_info(module)
  end

  def debug_info(beam) when is_binary(beam) do
    do_debug_info(beam)
  end

  # Private functions

  defp do_debug_info(module, path \\ nil)

  defp do_debug_info(module, _) when is_atom(module) do
    case :code.get_object_code(module) do
      {_, beam, beam_path} ->
        do_debug_info(beam, beam_path)

      :error ->
        {:error, "Unknown module: #{inspect(module)}"}
    end
  end

  defp do_debug_info(beam, beam_path) when is_binary(beam) do
    with {:ok, {module, [debug_info: {:debug_info_v1, backend, data}]}} <-
           :beam_lib.chunks(beam, [:debug_info]),
         {:ok, {^module, attribute_info}} <- :beam_lib.chunks(beam, [:attributes]) do
      # Check if this is a protocol
      if Keyword.get(attribute_info[:attributes], :protocol) do
        get_protocol_implementations(module, beam_path)
      else
        # Extract elixir_v1 debug info (macro-expanded AST)
        backend.debug_info(:elixir_v1, module, data, [])
        |> process_debug_info(beam_path)
      end
    else
      :error ->
        {:error, "Unknown module"}

      {:error, :beam_lib, {:unknown_chunk, _, :debug_info}} ->
        {:error, "Unsupported version of Erlang (requires Erlang 20+)"}

      {:error, :beam_lib, {:missing_chunk, _, _}} ->
        {:error, "Debug info not available. Compile with: MIX_ENV=dev mix compile"}

      {:error, :beam_lib, {:file_error, _, :enoent}} ->
        {:error, "BEAM file not found"}

      error ->
        {:error, "Failed to extract debug info: #{inspect(error)}"}
    end
  end

  defp process_debug_info({:ok, info}, nil) do
    info = Map.put(info, :last_modified, nil)
    {:ok, info}
  end

  defp process_debug_info({:ok, info}, beam_path) do
    info =
      case File.stat(beam_path, time: :posix) do
        {:ok, file_info} ->
          Map.put(info, :last_modified, file_info.mtime)

        _ ->
          Map.put(info, :last_modified, nil)
      end

    info = Map.put(info, :beam_path, beam_path)

    {:ok, info}
  end

  defp process_debug_info(error, _) do
    error
  end

  # Protocol handling (Phase 2+ - simplified for now)
  defp get_protocol_implementations(module, beam_path) do
    {:ok, protocol_module_info} = process_debug_info({:ok, %{}}, beam_path)

    implementations =
      module
      |> Protocol.extract_impls(:code.get_path())
      |> Enum.map(fn x -> Module.concat([module, x]) end)
      |> Enum.map(fn x ->
        case debug_info(x) do
          {:ok, info} ->
            {x, info}

          {:error, reason} ->
            raise "Unable to compile protocol implementation #{inspect(x)}: #{reason}"
        end
      end)

    {:ok, module, protocol_module_info, implementations}
  end
end

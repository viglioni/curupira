defmodule CurupiraJS.Error do
  @moduledoc """
  Error handling and formatting for CurupiraJS.

  Provides rich, helpful error messages with:
  - Source context
  - File and line numbers
  - Helpful hints for common issues
  - Color-coded output (when supported)
  """

  defstruct [:type, :message, :module, :file, :line, :hint, :context]

  @type t :: %__MODULE__{
          type: atom(),
          message: String.t(),
          module: module() | nil,
          file: String.t() | nil,
          line: integer() | nil,
          hint: String.t() | nil,
          context: term()
        }

  @doc """
  Create a new compilation error.
  """
  def compilation_error(module, reason, opts \\ []) do
    %__MODULE__{
      type: :compilation_error,
      message: format_compilation_error_message(reason),
      module: module,
      file: Keyword.get(opts, :file),
      line: Keyword.get(opts, :line),
      hint: suggest_hint(:compilation_error, reason),
      context: reason
    }
  end

  @doc """
  Create a translation error (unsupported Elixir construct).
  """
  def translation_error(expr, opts \\ []) do
    %__MODULE__{
      type: :translation_error,
      message: "Unsupported Elixir expression: #{format_expr(expr)}",
      module: Keyword.get(opts, :module),
      file: Keyword.get(opts, :file),
      line: extract_line(expr),
      hint: suggest_hint(:translation_error, expr),
      context: expr
    }
  end

  @doc """
  Create a validation error.
  """
  def validation_error(reason) do
    %__MODULE__{
      type: :validation_error,
      message: format_validation_error_message(reason),
      module: nil,
      file: nil,
      line: nil,
      hint: suggest_hint(:validation_error, reason),
      context: reason
    }
  end

  @doc """
  Format an error as a string for display.

  Accepts:
  - Error struct
  - Error tuple {:error, error_struct}
  - Generic error tuple {:error, reason}
  """
  def format(%__MODULE__{} = error) do
    [
      format_header(error),
      format_location(error),
      format_message(error),
      format_hint(error)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  def format({:error, %__MODULE__{} = error}), do: format(error)
  def format({:error, reason}), do: "Error: #{inspect(reason)}"

  # Private functions

  defp format_header(error) do
    type_str = format_error_type(error.type)
    IO.ANSI.format([:red, :bright, "** (#{type_str}) ", :reset]) |> IO.iodata_to_binary()
  end

  defp format_location(%{module: mod, file: file, line: line}) do
    parts = [
      if(mod, do: "in module #{inspect(mod)}"),
      if(file, do: "at #{file}"),
      if(line, do: "line #{line}")
    ]
    |> Enum.reject(&is_nil/1)

    if parts == [] do
      nil
    else
      "    " <> Enum.join(parts, ", ")
    end
  end

  defp format_message(%{message: message}) do
    "    " <> message
  end

  defp format_hint(%{hint: nil}), do: nil
  defp format_hint(%{hint: hint}) do
    IO.ANSI.format([:yellow, "\n    Hint: ", hint, :reset]) |> IO.iodata_to_binary()
  end

  defp format_error_type(:compilation_error), do: "CompilationError"
  defp format_error_type(:translation_error), do: "TranslationError"
  defp format_error_type(:validation_error), do: "ValidationError"
  defp format_error_type(type), do: inspect(type)

  defp format_compilation_error_message(:beam_not_found) do
    "Module not compiled or BEAM file not found"
  end

  defp format_compilation_error_message(:no_debug_info) do
    "BEAM file has no debug information (compile with debug_info: true)"
  end

  defp format_compilation_error_message({:unknown_module, module}) do
    "Unknown module: #{inspect(module)}"
  end

  defp format_compilation_error_message(reason) do
    "Compilation failed: #{inspect(reason)}"
  end

  defp format_validation_error_message(:empty_module_list) do
    "No modules provided for compilation"
  end

  defp format_validation_error_message({:invalid_module, value}) do
    "Invalid module name: #{inspect(value)} (expected atom)"
  end

  defp format_validation_error_message(reason) do
    "Validation failed: #{inspect(reason)}"
  end

  defp format_expr({name, _, _}) when is_atom(name) do
    to_string(name)
  end

  defp format_expr(expr) when is_tuple(expr) do
    inspect(expr, limit: 10)
  end

  defp format_expr(expr) do
    inspect(expr, limit: 10)
  end

  defp extract_line({_, meta, _}) when is_list(meta) do
    Keyword.get(meta, :line)
  end

  defp extract_line(_), do: nil

  # Hint suggestions based on error type and context

  defp suggest_hint(:compilation_error, :beam_not_found) do
    "Make sure the module is compiled. Try running 'mix compile' first."
  end

  defp suggest_hint(:compilation_error, :no_debug_info) do
    "Add 'debug_info: true' to your project's compiler options in mix.exs"
  end

  defp suggest_hint(:compilation_error, {:unknown_module, _module}) do
    "Make sure the module exists and is compiled. Check the module name for typos."
  end

  defp suggest_hint(:compilation_error, "Unknown module: " <> _) do
    "Make sure the module exists and is compiled. Check the module name for typos."
  end

  defp suggest_hint(:validation_error, :empty_module_list) do
    "Pass at least one module to compile, e.g., CurupiraJS.compile(MyModule)"
  end

  defp suggest_hint(:translation_error, {:fn, _, _}) do
    "Anonymous functions with multiple clauses are not yet supported. Try using a single clause with case/cond instead."
  end

  defp suggest_hint(:translation_error, {:<-, _, _}) do
    "Destructuring assignments in this context are not yet supported. Try pattern matching in function heads or case expressions instead."
  end

  defp suggest_hint(:translation_error, {:with, _, _}) do
    "The 'with' construct is not yet supported. Try using nested case expressions instead."
  end

  defp suggest_hint(:translation_error, {:for, _, _}) do
    "Comprehensions are not yet supported. Try using Enum.map/filter/reduce instead."
  end

  defp suggest_hint(:translation_error, {:try, _, _}) do
    "Try/catch/rescue is not yet fully supported. Error handling may be limited."
  end

  defp suggest_hint(:translation_error, {:receive, _, _}) do
    "The 'receive' construct is not supported in JavaScript (no message passing)."
  end

  defp suggest_hint(:translation_error, {:quote, _, _}) do
    "Macros and quote/unquote are not supported in JavaScript."
  end

  defp suggest_hint(_type, _context), do: nil
end

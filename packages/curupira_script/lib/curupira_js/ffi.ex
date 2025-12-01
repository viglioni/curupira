defmodule CurupiraJS.FFI do
  @moduledoc """
  Foreign Function Interface (FFI) for calling JavaScript from Elixir.

  Provides macros for defining JavaScript function bindings that feel natural in Elixir.

  ## Features

  - **Type-safe bindings**: Declare argument and return types
  - **Struct wrappers**: Wrap JavaScript objects in Elixir structs with `__ref__` pattern
  - **Elixir idioms**: Returns `{:ok, result}` / `{:error, reason}` tuples
  - **Inline or external JS**: Define JavaScript inline or reference external functions

  ## Example Usage

  ```elixir
  defmodule MyApp.Console do
    use CurupiraJS.FFI

    # Simple JS function call
    ffi :log,
      js_path: "console.log",
      args: [any()],
      returns: :ok

    # Custom JavaScript implementation
    ffi :fetch_json,
      args: [string()],
      returns: {:result, map()},
      js: \"\"\"
      async (url) => {
        try {
          const response = await fetch(url);
          const data = await response.json();
          return { ok: true, data };
        } catch (error) {
          return { ok: false, error: error.message };
        }
      }
      \"\"\"
  end
  ```

  ## Struct Wrappers

  For wrapping JavaScript objects (like DOM elements, Canvas contexts, etc.):

  ```elixir
  defmodule MyApp.Canvas do
    use CurupiraJS.FFI

    # Define a struct to represent the JS object
    defstruct [:width, :height, :__ref__]

    @type t :: %__MODULE__{
      width: integer(),
      height: integer(),
      __ref__: reference()
    }

    # Get canvas context - wraps in struct
    ffi :get_context,
      js_path: "HTMLCanvasElement.prototype.getContext",
      args: [string()],
      returns: {:option, t()},
      wrapper: true

    # Method that takes wrapped struct
    ffi :fill_rect,
      args: [t(), integer(), integer(), integer(), integer()],
      returns: t(),
      js: \"\"\"
      (ctx, x, y, width, height) => {
        ctx.__ref__.fillRect(x, y, width, height);
        return ctx;
      }
      \"\"\"
  end
  ```

  ## Return Types

  - `:ok` - Returns `:ok` atom
  - `any()` - Returns value as-is
  - `t()` - Returns struct (requires `wrapper: true`)
  - `{:ok, type}` - Returns `{:ok, value}` tuple
  - `{:error, type}` - Returns `{:error, reason}` tuple
  - `{:result, type}` - Returns `{:ok, value}` or `{:error, reason}` based on JS object shape
  - `{:option, type}` - Returns `{:ok, value}` if not null, `{:error, :not_found}` if null

  ## Options

  - `:js_path` - Path to JavaScript function (e.g., "document.getElementById")
  - `:js` - Inline JavaScript function implementation
  - `:args` - List of argument types
  - `:returns` - Return type specification
  - `:wrapper` - Boolean, whether to wrap JS object in struct (default: false)
  - `:async` - Boolean, whether JS function is async (default: auto-detected)
  """

  @doc """
  When `use CurupiraJS.FFI` is called, it:
  1. Imports the `ffi/2` macro
  2. Registers module attributes for tracking FFI functions
  3. Sets up the before_compile hook
  """
  defmacro __using__(_opts) do
    quote do
      import CurupiraJS.FFI, only: [ffi: 2]
      Module.register_attribute(__MODULE__, :ffi_functions, accumulate: true)
      Module.register_attribute(__MODULE__, :ffi_module, persist: true)
      @ffi_module true
      @before_compile CurupiraJS.FFI
    end
  end

  @doc """
  Define a Foreign Function Interface binding to JavaScript.

  ## Arguments

  - `name` - The Elixir function name (atom)
  - `opts` - Keyword list of options

  ## Options

  - `:js_path` - JavaScript function path (e.g., "Math.random")
  - `:js` - Inline JavaScript function (string)
  - `:args` - List of argument type specifications
  - `:returns` - Return type specification
  - `:wrapper` - Wrap result in module's struct (default: false)
  - `:async` - JavaScript function is async (default: auto-detect from `:js`)

  ## Examples

      # External JS function
      ffi :random, js_path: "Math.random", args: [], returns: float()

      # Inline JS function
      ffi :add, args: [integer(), integer()], returns: integer(),
        js: "(a, b) => a + b"

      # With result type
      ffi :fetch, args: [string()], returns: {:result, map()},
        js: \"\"\"
        async (url) => {
          try {
            const res = await fetch(url);
            return { ok: true, data: await res.json() };
          } catch (e) {
            return { ok: false, error: e.message };
          }
        }
        \"\"\"
  """
  defmacro ffi(name, opts) when is_atom(name) and is_list(opts) do
    quote bind_quoted: [name: name, opts: opts] do
      # Validate options
      unless Keyword.has_key?(opts, :js_path) or Keyword.has_key?(opts, :js) do
        raise ArgumentError,
              "FFI function #{name} must specify either :js_path or :js option"
      end

      # Store FFI function metadata
      @ffi_functions {name, opts}

      # Generate Elixir function stub
      # The actual implementation will be in JavaScript
      # This is just for documentation and type specs
      args = Keyword.get(opts, :args, [])
      arg_vars = for i <- 0..(length(args) - 1), do: Macro.var(:"arg#{i}", __MODULE__)

      @doc """
      FFI binding to JavaScript.

      #{if Keyword.has_key?(opts, :js_path), do: "Calls: `#{Keyword.get(opts, :js_path)}`"}

      Args: #{inspect(Keyword.get(opts, :args, []))}
      Returns: #{inspect(Keyword.get(opts, :returns, :any))}
      """
      def unquote(name)(unquote_splicing(arg_vars)) do
        raise """
        FFI function #{unquote(name)} can only be called from JavaScript.

        This function is compiled to JavaScript and is not available in Elixir runtime.
        Make sure you:
        1. Compile this module with CurupiraJS.compile/2
        2. Call this function from the generated JavaScript bundle

        Example:
            {:ok, _} = CurupiraJS.compile([#{inspect(__MODULE__)}])
        """
      end
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    ffi_functions = Module.get_attribute(env.module, :ffi_functions)

    quote do
      @doc false
      def __ffi_functions__ do
        unquote(Macro.escape(ffi_functions))
      end

      @doc false
      def __ffi_module__?, do: true
    end
  end

  @doc """
  Check if a module uses FFI.
  """
  def ffi_module?(module) do
    function_exported?(module, :__ffi_module__?, 0) and module.__ffi_module__?()
  rescue
    _ -> false
  end

  @doc """
  Get FFI function definitions from a module.
  """
  def get_ffi_functions(module) do
    if ffi_module?(module) do
      {:ok, module.__ffi_functions__()}
    else
      {:error, :not_ffi_module}
    end
  end
end

defmodule CurupiraJS do
  @moduledoc """
  CurupiraJS - Elixir to JavaScript transpiler.

  Compiles Elixir code to modern JavaScript (ES2020+) for client-side web applications.

  ## Usage

  Add to your `mix.exs`:

      def project do
        [
          compilers: Mix.compilers() ++ [:curupira_js],
          curupira_js: [
            input: MyApp,
            output: "assets/js"
          ]
        ]
      end

  Then compile:

      mix compile

  ## Configuration

  Available options:

    * `:input` (required) - Entry module or list of modules to compile
    * `:output` (optional) - Output directory. Defaults to `priv/curupira_js/build`
    * `:source_maps` (optional) - Generate source maps. Defaults to `true` in dev
    * `:format` (optional) - Output format (only `:es` supported). Defaults to `:es`

  ## Example

      defmodule MyApp do
        def greet(name) do
          "Hello, \#{name}!"
        end
      end

  Compiles to:

      // js/Elixir.MyApp.js
      export default {
        greet(name) {
          return `Hello, \${name}!`;
        }
      };

  ## Status

  🚧 **Under Development** - Currently in Phase 0 (Architecture Study)

  See https://github.com/your-org/curupira for more information.
  """

  @doc """
  Compile Elixir module(s) to JavaScript.

  ## Options

    * `:output` - Output directory or file path
    * `:source_maps` - Generate source maps (default: true in dev)

  ## Examples

      # Compile single module
      CurupiraJS.compile(MyApp)

      # Compile multiple modules
      CurupiraJS.compile([MyApp, MyApp.Utils])

      # With options
      CurupiraJS.compile(MyApp, output: "dist/js", source_maps: true)

  """
  @spec compile(module() | [module()], keyword()) :: {:ok, map()} | {:error, term()}
  def compile(modules, opts \\ []) do
    CurupiraJS.Compiler.compile(modules, opts)
  end

  @doc """
  Get the version of CurupiraJS.
  """
  @spec version() :: String.t()
  def version do
    case Application.spec(:curupira_js, :vsn) do
      vsn when is_list(vsn) -> List.to_string(vsn)
      _ -> "0.33.0-dev"
    end
  end
end

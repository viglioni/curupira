defmodule Mix.Tasks.Compile.CurupiraJs do
  use Mix.Task.Compiler

  @moduledoc """
  Compiles Elixir modules to JavaScript and generates a bundle.

  This is a Mix compiler task that integrates with `mix compile`.

  ## Configuration

      # mix.exs
      def project do
        [
          compilers: Mix.compilers() ++ [:curupira_js],
          curupira_js: [
            input: [MyApp.Site],
            output: "js/elixir_bundle.js"
          ]
        ]
      end

  Now running `mix compile` will automatically build your JavaScript bundle.
  """

  @impl Mix.Task.Compiler
  def run(_args) do
    Mix.Compilers.CurupiraJs.run([])
  end

  @impl Mix.Task.Compiler
  def clean do
    Mix.Compilers.CurupiraJS.clean()
  end

  @impl Mix.Task.Compiler
  def manifests do
    Mix.Compilers.CurupiraJS.manifests()
  end
end

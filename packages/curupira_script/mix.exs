defmodule CurupiraJS.MixProject do
  use Mix.Project

  @version "0.33.0-dev"
  @source_url "https://github.com/your-org/curupira"

  def project do
    [
      app: :curupira_js,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      compilers: Mix.compilers() ++ [:curupira_js],
      deps: deps(),

      # Hex
      description: description(),
      package: package(),

      # Docs
      name: "CurupiraJS",
      source_url: @source_url,
      docs: docs(),

      # CurupiraJS configuration (example)
      curupira_js: [
        input: [Fixtures.Simple, Fixtures.WithArgs],
        output: "js/elixir_bundle.js"
      ],

      # Testing
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],

      # Dialyzer
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Core dependencies (from ElixirScript)
      {:estree, "~> 2.6"},

      # Watch mode (also used by credo)
      {:file_system, "~> 1.0", only: [:dev, :test]},

      # Development & Testing
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:typed_struct, "~> 0.3.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    Elixir to JavaScript transpiler for client-side applications.
    Modern fork of ElixirScript supporting Elixir 1.17+.
    """
  end

  defp package do
    [
      name: "curupira_script",
      files: ~w(lib priv .formatter.exs mix.exs readme.org LICENSE CHANGELOG.org),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/packages/curupira_script/CHANGELOG.org"
      },
      maintainers: ["Curupira Team"]
    ]
  end

  defp docs do
    [
      main: "CurupiraJS",
      source_ref: "curupira_script-v#{@version}",
      source_url: @source_url,
      extras: [
        "readme.org",
        "CHANGELOG.org"
      ]
    ]
  end
end

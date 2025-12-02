defmodule Curupira.MixProject do
  use Mix.Project

  def project do
    [
      app: :curupira,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Mix template for CurupiraJS applications",
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:mix_templates, "~> 0.3.0"}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/viglioni/curupira"
      },
      files: ~w(lib template mix.exs README.md)
    ]
  end
end

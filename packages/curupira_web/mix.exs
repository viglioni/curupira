defmodule CurupiraWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :curupira_web,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Web/DOM bindings for CurupiraJS - Elixir to JavaScript transpiler",
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
      # Local dependency on curupira_js
      {:curupira_js, path: "../curupira_script"},

      # Development dependencies
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/viglioni/curupira"}
    ]
  end
end

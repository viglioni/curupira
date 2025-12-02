defmodule <%= @project_name_camel_case %>.MixProject do
  use Mix.Project

  def project do
    [
      app: :<%= @project_name %>,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: Mix.compilers() ++ [:curupira_js],
      # CurupiraJS configuration
      curupira_js: [
        # Entry module. Can also be a list of modules
        input: <%= @project_name_camel_case %>,
        output: "priv/static/js/app.js"
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
      {:curupira_js, path: "../curupira_script"},
      {:curupira_web, path: "../curupira_web"},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:file_system, "~> 1.0", only: :dev}
    ]
  end
end

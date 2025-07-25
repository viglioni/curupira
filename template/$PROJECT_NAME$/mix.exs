defmodule <%= @project_name_camel_case %>.MixProject do
  use Mix.Project

  def project do
    [
      app: :<%= @project_name %>,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
			compilers: Mix.compilers() ++ [:elixir_script],
      # Our elixir_script configuration
      elixir_script: [
        # Entry module. Can also be a list of modules
        input: <%= @project_name_camel_case %>,
        output: "js"
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
      {:elixir_script_web, "~> 0.2"},
      {:elixir_script, "~> 0.32.1"},
      {:mix_test_watch, "~> 1.0", only: :dev},
      {:exsync, "~> 0.4", only: [:dev, :test]}
    ]
  end
end

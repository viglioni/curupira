defmodule ElixirFrontendTemplate do
  @moduledoc """
  Documentation for `ElixirFrontendTemplate`.
  """

  use MixTemplates,
    name: :elixir_frontend,
    short_desc: "Template for client side rendered frontends using Elixir",
    source_dir: "template"

  def available_templates do
    [
      {"default"}
    ]
  end

  def populate_assigns(assigns, _opts) do
    assigns
    |> Keyword.put(:year, Date.utc_today().year)
  end
end

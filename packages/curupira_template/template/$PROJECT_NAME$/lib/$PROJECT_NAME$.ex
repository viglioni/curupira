defmodule <%= @project_name_camel_case %> do
  @moduledoc """
  Main entry point for <%= @project_name_camel_case %> application.

  This module uses CurupiraJS to compile Elixir to JavaScript,
  and CurupiraWeb for DOM manipulation.
  """

  alias CurupiraWeb.DOM

  @doc """
  Application entry point.
  Called when the JavaScript bundle loads.
  """
  @spec main() :: :ok
  def main do
    IO.puts("Starting <%= @project_name_camel_case %>...")
    setup_app()
  end

  defp setup_app do
    # Find or create the app container
    case DOM.query_selector("#app") do
      {:ok, app} ->
        # Create a welcome message
        {:ok, heading} = DOM.create_element("h1")
        heading = DOM.set_inner_text(heading, "Welcome to <%= @project_name_camel_case %>!")
        heading = DOM.add_class(heading, "title")

        {:ok, paragraph} = DOM.create_element("p")
        paragraph = DOM.set_inner_text(paragraph, "Built with CurupiraJS - Elixir compiled to JavaScript")
        paragraph = DOM.add_class(paragraph, "subtitle")

        {:ok, button} = DOM.create_element("button")
        button = DOM.set_inner_text(button, "Click me!")
        button = DOM.add_class(button, "btn")

        # Add click handler
        button = DOM.on_click(button, fn _event ->
          IO.puts("Button clicked!")
          case DOM.query_selector(".message") do
            {:ok, msg} -> DOM.set_inner_text(msg, "Button was clicked at #{DateTime.utc_now()}")
            :error -> :ok
          end
        end)

        {:ok, message} = DOM.create_element("div")
        message = DOM.add_class(message, "message")
        message = DOM.set_inner_text(message, "Click the button above!")

        # Build the UI
        app = DOM.append_child(app, heading)
        app = DOM.append_child(app, paragraph)
        app = DOM.append_child(app, button)
        _app = DOM.append_child(app, message)

        :ok

      :error ->
        IO.puts("Warning: #app element not found in HTML")
        :ok
    end
  end
end

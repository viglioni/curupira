defmodule CurupiraWeb do
  @moduledoc """
  Web/DOM bindings for CurupiraJS.

  Provides type-safe Elixir structs and FFI bindings for working with
  browser DOM APIs. All DOM operations compile to JavaScript and run
  in the browser.

  ## Modules

  - `CurupiraWeb.DOM` - Main DOM manipulation module
  - `CurupiraWeb.DOM.Element` - Generic DOM element struct
  - `CurupiraWeb.DOM.Input` - Input element struct
  - `CurupiraWeb.DOM.Button` - Button element struct
  - `CurupiraWeb.DOM.Canvas` - Canvas element struct
  - `CurupiraWeb.DOM.Form` - Form element struct

  ## Example Usage

      # Query the DOM
      {:ok, app} = DOM.query_selector("#app")

      # Create and manipulate elements
      {:ok, div} = DOM.create_element("div")
      div = DOM.set_inner_text(div, "Hello, World!")
      div = DOM.add_class(div, "container")

      # Append to DOM
      app = DOM.append_child(app, div)

  ## Compilation

  To use CurupiraWeb, compile your modules with CurupiraJS:

      # In mix.exs
      curupira_js: [
        input: [MyApp.Main],
        output: "priv/static/js/app.js"
      ]

      # Run: mix curupira_js.build

  ## Architecture

  All DOM elements use the `__ref__` pattern to wrap actual JavaScript
  DOM Element objects while maintaining an immutable Elixir struct facade.

  This allows you to write functional Elixir code that compiles to efficient
  imperative JavaScript DOM manipulations.
  """

  @doc """
  Returns the version of CurupiraWeb.
  """
  def version do
    case Application.spec(:curupira_web, :vsn) do
      vsn when is_list(vsn) -> List.to_string(vsn)
      _ -> "0.1.0"
    end
  end
end

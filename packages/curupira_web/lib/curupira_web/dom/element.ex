defmodule CurupiraWeb.DOM.Element do
  @moduledoc """
  Base struct for all DOM elements.

  Uses the `__ref__` pattern to wrap JavaScript DOM Element objects
  in an immutable Elixir struct.

  ## Fields

  - `:tag_name` - The HTML tag name (e.g., "div", "span", "p")
  - `:id` - The element's ID attribute
  - `:class_name` - The element's class attribute (space-separated string)
  - `:inner_html` - The element's innerHTML
  - `:inner_text` - The element's innerText
  - `:value` - The element's value (for inputs, textareas, etc.)
  - `:__ref__` - Reference to the actual JavaScript DOM element

  ## Example

      # This struct wraps a JS element like:
      # <div id="app" class="container">Hello</div>

      %CurupiraWeb.DOM.Element{
        tag_name: "div",
        id: "app",
        class_name: "container",
        inner_html: "Hello",
        inner_text: "Hello",
        __ref__: #Reference<...>
      }
  """

  defstruct [
    :tag_name,
    :id,
    :class_name,
    :inner_html,
    :inner_text,
    :value,
    :__ref__
  ]

  @type t :: %__MODULE__{
          tag_name: String.t(),
          id: String.t() | nil,
          class_name: String.t() | nil,
          inner_html: String.t() | nil,
          inner_text: String.t() | nil,
          value: String.t() | nil,
          __ref__: reference()
        }
end

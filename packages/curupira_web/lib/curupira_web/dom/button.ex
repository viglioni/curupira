defmodule CurupiraWeb.DOM.Button do
  @moduledoc """
  Struct representing an HTML `<button>` element.

  ## Fields

  - `:type` - Button type ("button", "submit", "reset")
  - `:disabled` - Whether the button is disabled
  - `:inner_text` - Button text content

  ## Example

      %CurupiraWeb.DOM.Button{
        tag_name: "button",
        type: "submit",
        inner_text: "Click me",
        class_name: "btn btn-primary",
        __ref__: #Reference<...>
      }
  """

  defstruct [
    :tag_name,
    :id,
    :class_name,
    :type,
    :inner_text,
    :disabled,
    :__ref__
  ]

  @type t :: %__MODULE__{
          tag_name: String.t(),
          id: String.t() | nil,
          class_name: String.t() | nil,
          type: String.t(),
          inner_text: String.t() | nil,
          disabled: boolean(),
          __ref__: reference()
        }
end

defmodule CurupiraWeb.DOM.Input do
  @moduledoc """
  Struct representing an HTML `<input>` element.

  Extends the base Element with input-specific fields.

  ## Additional Fields

  - `:type` - Input type (e.g., "text", "email", "password", "checkbox")
  - `:placeholder` - Placeholder text
  - `:disabled` - Whether the input is disabled
  - `:checked` - Whether the checkbox/radio is checked
  - `:required` - Whether the input is required

  ## Example

      %CurupiraWeb.DOM.Input{
        tag_name: "input",
        type: "email",
        value: "user@example.com",
        placeholder: "Enter your email",
        required: true,
        __ref__: #Reference<...>
      }
  """

  defstruct [
    :tag_name,
    :id,
    :class_name,
    :type,
    :value,
    :placeholder,
    :disabled,
    :checked,
    :required,
    :__ref__
  ]

  @type t :: %__MODULE__{
          tag_name: String.t(),
          id: String.t() | nil,
          class_name: String.t() | nil,
          type: String.t(),
          value: String.t() | nil,
          placeholder: String.t() | nil,
          disabled: boolean(),
          checked: boolean(),
          required: boolean(),
          __ref__: reference()
        }
end

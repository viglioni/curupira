defmodule CurupiraWeb.DOM.Form do
  @moduledoc """
  Struct representing an HTML `<form>` element.

  ## Fields

  - `:action` - Form action URL
  - `:method` - HTTP method ("GET" or "POST")
  - `:enctype` - Encoding type for form data

  ## Example

      %CurupiraWeb.DOM.Form{
        tag_name: "form",
        action: "/submit",
        method: "POST",
        id: "contact-form",
        __ref__: #Reference<...>
      }
  """

  defstruct [
    :tag_name,
    :id,
    :class_name,
    :action,
    :method,
    :enctype,
    :__ref__
  ]

  @type t :: %__MODULE__{
          tag_name: String.t(),
          id: String.t() | nil,
          class_name: String.t() | nil,
          action: String.t() | nil,
          method: String.t(),
          enctype: String.t() | nil,
          __ref__: reference()
        }
end

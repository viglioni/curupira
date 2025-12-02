defmodule CurupiraWeb.DOM.Canvas do
  @moduledoc """
  Struct representing an HTML `<canvas>` element.

  ## Fields

  - `:width` - Canvas width in pixels
  - `:height` - Canvas height in pixels
  - `:context_2d` - Reference to the 2D rendering context (if obtained)

  ## Example

      %CurupiraWeb.DOM.Canvas{
        tag_name: "canvas",
        width: 800,
        height: 600,
        id: "game-canvas",
        __ref__: #Reference<...>
      }
  """

  defstruct [
    :tag_name,
    :id,
    :class_name,
    :width,
    :height,
    :context_2d,
    :__ref__
  ]

  @type t :: %__MODULE__{
          tag_name: String.t(),
          id: String.t() | nil,
          class_name: String.t() | nil,
          width: integer(),
          height: integer(),
          context_2d: reference() | nil,
          __ref__: reference()
        }
end

defmodule CurupiraWeb.DOM.Event do
  @moduledoc """
  Struct representing a DOM Event.

  Wraps JavaScript Event objects with common event properties.

  ## Fields

  - `:type` - Event type (e.g., "click", "change", "submit")
  - `:target` - The element that triggered the event
  - `:current_target` - The element the listener is attached to
  - `:default_prevented` - Whether preventDefault was called
  - `:bubbles` - Whether the event bubbles
  - `:cancelable` - Whether the event is cancelable
  - `:timestamp` - Event timestamp
  - `:__ref__` - Reference to the actual JavaScript Event object

  ## Example

      # In an event handler:
      def handle_click(event) do
        # event is an Event struct
        IO.inspect(event.type)      # "click"
        IO.inspect(event.target)    # Element struct
      end
  """

  alias CurupiraWeb.DOM.Element

  defstruct [
    :type,
    :target,
    :current_target,
    :default_prevented,
    :bubbles,
    :cancelable,
    :timestamp,
    :__ref__
  ]

  @type t :: %__MODULE__{
          type: String.t(),
          target: Element.t() | nil,
          current_target: Element.t() | nil,
          default_prevented: boolean(),
          bubbles: boolean(),
          cancelable: boolean(),
          timestamp: integer(),
          __ref__: reference()
        }
end

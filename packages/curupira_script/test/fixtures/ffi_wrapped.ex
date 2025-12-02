defmodule Fixtures.FFIWrapped do
  @moduledoc """
  Example FFI module demonstrating struct wrappers with __ref__ pattern.

  This shows how to wrap JavaScript objects (like Canvas, DOM elements, etc.)
  in Elixir structs while maintaining an immutable facade.
  """

  use CurupiraJS.FFI

  # Define struct to wrap the Canvas context
  defstruct [:width, :height, :fill_style, :__ref__]

  @type t :: %__MODULE__{
    width: integer(),
    height: integer(),
    fill_style: String.t(),
    __ref__: reference()
  }

  # Get a mock canvas context (for testing)
  # Returns wrapped struct
  ffi :create_context,
    args: [:integer, :integer],
    returns: t(),
    wrapper: true,
    js: """
    (width, height) => {
      return {
        width: width,
        height: height,
        fillStyle: '#000000',
        _jsRef: {
          fillRect: function() {},
          clearRect: function() {}
        }
      };
    }
    """

  # Set fill style - takes wrapped struct, returns new wrapped struct
  # This demonstrates the immutable facade over mutable JS
  ffi :set_fill_style,
    args: [t(), :string],
    returns: t(),
    wrapper: true,
    js: """
    (ctx, color) => {
      return { ...ctx, fillStyle: color };
    }
    """

  # Draw rectangle - takes wrapped struct, mutates underlying JS, returns updated struct
  ffi :fill_rect,
    args: [t(), :integer, :integer, :integer, :integer],
    returns: t(),
    wrapper: true,
    js: """
    (ctx, x, y, w, h) => {
      if (ctx._jsRef && ctx._jsRef.fillRect) {
        ctx._jsRef.fillRect(x, y, w, h);
      }
      return ctx;
    }
    """

  # Get width - takes wrapped struct, returns plain value
  ffi :get_width,
    args: [t()],
    returns: :integer,
    wrapper: true,
    js: "(ctx) => ctx.width"

  # Example with option type - may return null
  ffi :try_get_context,
    args: [:integer, :integer],
    returns: {:option, t()},
    wrapper: true,
    js: """
    (width, height) => {
      if (width <= 0 || height <= 0) {
        return null;
      }
      return {
        width: width,
        height: height,
        fillStyle: '#000000',
        _jsRef: {}
      };
    }
    """
end

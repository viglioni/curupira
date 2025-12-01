defmodule Fixtures.FFIExample do
  use CurupiraJS.FFI

  # Simple external JS function
  ffi :random,
    js_path: "Math.random",
    args: [],
    returns: :any

  # Inline JS function with arguments
  ffi :add,
    args: [:integer, :integer],
    returns: :integer,
    js: "(a, b) => a + b"

  # Function with {:ok, _} return
  ffi :safe_divide,
    args: [:number, :number],
    returns: {:ok, :number},
    js: """
    (a, b) => {
      if (b === 0) {
        throw new Error("Division by zero");
      }
      return a / b;
    }
    """

  # Function with {:result, _} return (auto ok/error based on JS object)
  ffi :parse_int,
    args: [:string],
    returns: {:result, :integer},
    js: """
    (str) => {
      const num = parseInt(str, 10);
      if (isNaN(num)) {
        return { ok: false, error: "Not a number" };
      }
      return { ok: true, data: num };
    }
    """
end

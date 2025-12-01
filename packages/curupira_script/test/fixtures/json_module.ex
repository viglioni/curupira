defmodule Fixtures.JSONModule do
  @moduledoc """
  Test fixture for JSON module (Elixir 1.18+)
  """

  # Basic encoding
  def encode_map do
    JSON.encode!(%{name: "Alice", age: 30})
  end

  def encode_list do
    JSON.encode!([1, 2, 3, 4, 5])
  end

  def encode_string do
    JSON.encode!("hello world")
  end

  def encode_number do
    JSON.encode!(42)
  end

  def encode_boolean do
    JSON.encode!(true)
  end

  def encode_nil do
    JSON.encode!(nil)
  end

  # Nested structures
  def encode_nested do
    JSON.encode!(%{
      user: %{name: "Bob", email: "bob@example.com"},
      items: [%{id: 1, name: "Item 1"}, %{id: 2, name: "Item 2"}]
    })
  end

  # Decoding
  def decode_object do
    JSON.decode!(~s({"name":"Alice","age":30}))
  end

  def decode_array do
    JSON.decode!("[1,2,3,4,5]")
  end

  def decode_string do
    JSON.decode!(~s("hello world"))
  end

  def decode_number do
    JSON.decode!("42")
  end

  def decode_boolean do
    JSON.decode!("true")
  end

  def decode_null do
    JSON.decode!("null")
  end

  # Safe versions (return tuples)
  def encode_safe(data) do
    JSON.encode(data)
  end

  def decode_safe(json) do
    JSON.decode(json)
  end

  # Roundtrip
  def roundtrip(data) do
    data
    |> JSON.encode!()
    |> JSON.decode!()
  end

  # With atoms option for decode
  def decode_atoms_as_keys do
    case JSON.decode(~s({"name":"Alice","age":30}), keys: :atoms) do
      {:ok, result} -> result
      {:error, _} -> nil
    end
  end
end

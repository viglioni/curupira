defmodule CurupiraScript.Translator do
  @moduledoc """
  Translates Elixir AST expressions to ESTree JavaScript AST.
  """

  alias ESTree.Tools.Builder, as: J

  @doc """
  Translate an Elixir expression to JavaScript AST.

  ## Examples

      iex> translate("hello")
      %ESTree.Literal{value: "hello"}

      iex> translate(42)
      %ESTree.Literal{value: 42}

      iex> translate(:ok)
      %ESTree.CallExpression{...}  # Symbol.for("ok")

  """
  def translate(expr)

  # Strings
  def translate(value) when is_binary(value) do
    J.literal(value)
  end

  # Integers
  def translate(value) when is_integer(value) do
    J.literal(value)
  end

  # Floats
  def translate(value) when is_float(value) do
    J.literal(value)
  end

  # Booleans
  def translate(true), do: J.literal(true)
  def translate(false), do: J.literal(false)

  # Nil
  def translate(nil), do: J.literal(nil)

  # Atoms (convert to Symbol.for("atom_name"))
  def translate(value) when is_atom(value) do
    J.call_expression(
      J.member_expression(
        J.identifier("Symbol"),
        J.identifier("for")
      ),
      [J.literal(Atom.to_string(value))]
    )
  end

  # Lists (arrays)
  def translate(list) when is_list(list) do
    elements = Enum.map(list, &translate/1)
    J.array_expression(elements)
  end

  # Tuples (convert to {__tuple__: true, values: [...]})
  def translate({:{}, _meta, elements}) do
    values = Enum.map(elements, &translate/1)

    J.object_expression([
      J.property(
        J.identifier("__tuple__"),
        J.literal(true)
      ),
      J.property(
        J.identifier("values"),
        J.array_expression(values)
      )
    ])
  end

  # 2-tuples (special case)
  def translate({a, b}) do
    translate({:{}, [], [a, b]})
  end

  # Maps
  def translate({:%{}, _meta, pairs}) do
    properties =
      Enum.map(pairs, fn {key, value} ->
        # For now, convert atom keys to strings
        key_js =
          cond do
            is_atom(key) -> J.literal(Atom.to_string(key))
            is_binary(key) -> J.literal(key)
            true -> translate(key)
          end

        J.property(key_js, translate(value))
      end)

    J.object_expression(properties)
  end

  # String interpolation: {:<<>>, meta, parts}
  def translate({:<<>>, _meta, parts}) when is_list(parts) do
    # For now, just handle simple strings and skip template literals
    # TODO: Properly implement template literals
    case extract_simple_string(parts) do
      {:ok, str} ->
        J.literal(str)

      :error ->
        # Has interpolation - for now, just return a concatenation
        build_string_concatenation(parts)
    end
  end

  # Binary operators
  def translate({op, _meta, [left, right]})
      when op in [:+, :-, :*, :/, :==, :!=, :<, :>, :<=, :>=, :and, :or] do
    js_op = elixir_op_to_js(op)
    J.binary_expression(js_op, translate(left), translate(right))
  end

  # Variable references
  def translate({var, _meta, nil}) when is_atom(var) do
    J.identifier(Atom.to_string(var))
  end

  # Function calls (local)
  def translate({func, _meta, args}) when is_atom(func) and is_list(args) do
    J.call_expression(
      J.identifier(Atom.to_string(func)),
      Enum.map(args, &translate/1)
    )
  end

  # Remote function calls: Module.function(args)
  def translate({{:., _meta1, [module, func]}, _meta2, args}) do
    module_name = module_to_string(module)
    func_name = Atom.to_string(func)

    J.call_expression(
      J.member_expression(
        J.identifier(module_name),
        J.identifier(func_name)
      ),
      Enum.map(args, &translate/1)
    )
  end

  # Blocks: (expr1; expr2; expr3)
  def translate({:__block__, _meta, exprs}) when is_list(exprs) do
    # For a block, we return the last expression
    # But in a function body context, we'll handle this differently
    translate(List.last(exprs))
  end

  # Catch-all for unsupported expressions
  def translate(expr) do
    # For now, return null for anything we don't support yet
    # TODO: Add proper error handling
    IO.warn("Unsupported expression: #{inspect(expr)}")
    J.literal(nil)
  end

  # Private helpers

  defp extract_simple_string(parts) do
    case Enum.all?(parts, &is_binary/1) do
      true ->
        # Simple string, no interpolation
        {:ok, IO.iodata_to_binary(parts)}

      false ->
        # Has interpolation
        :error
    end
  end

  defp build_string_concatenation(parts) do
    # Build string concatenation using + operator
    # parts: [{:"::", meta, [content, {:binary, ...}]}, ...]
    segments =
      Enum.map(parts, fn
        {:"::", _, [content, {:binary, _, _}]} ->
          case content do
            str when is_binary(str) ->
              J.literal(str)

            # Call to String.Chars.to_string
            {{:., _, [String.Chars, :to_string]}, _, [expr]} ->
              translate(expr)

            other ->
              translate(other)
          end

        part when is_binary(part) ->
          J.literal(part)

        other ->
          translate(other)
      end)

    # Chain with + operators
    case segments do
      [] ->
        J.literal("")

      [single] ->
        single

      [first | rest] ->
        Enum.reduce(rest, first, fn segment, acc ->
          J.binary_expression(:+, acc, segment)
        end)
    end
  end

  defp elixir_op_to_js(:+), do: :+
  defp elixir_op_to_js(:-), do: :-
  defp elixir_op_to_js(:*), do: :*
  defp elixir_op_to_js(:/), do: :/
  defp elixir_op_to_js(:==), do: :===
  defp elixir_op_to_js(:!=), do: :!==
  defp elixir_op_to_js(:<), do: :<
  defp elixir_op_to_js(:>), do: :>
  defp elixir_op_to_js(:<=), do: :<=
  defp elixir_op_to_js(:>=), do: :>=
  defp elixir_op_to_js(:and), do: :&&
  defp elixir_op_to_js(:or), do: :||

  defp module_to_string({:__aliases__, _meta, parts}) do
    Enum.map_join(parts, ".", &Atom.to_string/1)
  end

  defp module_to_string(module) when is_atom(module) do
    Atom.to_string(module)
  end
end

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
    # Check if it's a simple string or has interpolation
    case extract_string_parts(parts) do
      {:simple, binary} ->
        J.literal(binary)

      {:interpolated, segments} ->
        # Convert to template literal
        build_template_literal(segments)
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

  defp extract_string_parts(parts) do
    case Enum.all?(parts, &is_binary/1) do
      true ->
        # Simple string, no interpolation
        {:simple, IO.iodata_to_binary(parts)}

      false ->
        # Has interpolation
        segments =
          Enum.map(parts, fn
            part when is_binary(part) ->
              {:string, part}

            {:"::", _meta, [expr, {:binary, _meta2, _}]} ->
              {:expr, expr}

            other ->
              {:expr, other}
          end)

        {:interpolated, segments}
    end
  end

  defp build_template_literal(segments) do
    # Build template literal: `Hello ${name}!`
    {quasis, expressions} =
      Enum.reduce(segments, {[], []}, fn
        {:string, str}, {quasis, exprs} ->
          {quasis ++ [str], exprs}

        {:expr, expr}, {quasis, exprs} ->
          # Add empty string if needed to maintain structure
          {quasis ++ [""], exprs ++ [translate(expr)]}
      end)

    # ESTree template literal
    quasi_elements =
      quasis
      |> Enum.with_index()
      |> Enum.map(fn {str, idx} ->
        tail = idx == length(quasis) - 1
        # template_element(raw, cooked_value, tail, loc \\ nil)
        J.template_element(str, str, tail)
      end)

    J.template_literal(quasi_elements, expressions)
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

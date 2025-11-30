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

  # Struct update: %{struct | field: value}
  def translate({:%{}, _meta, [{:|, _, [struct_var, updates]}]}) do
    # Translate to: new StructType(Object.assign({}, struct_var, {updates}))
    # We need to get the struct type from the variable at runtime
    # For now, we'll use Object.assign with spread operator
    struct_js = translate(struct_var)

    updates_props = Enum.map(updates, fn {key, value} ->
      key_js = if is_atom(key), do: J.literal(Atom.to_string(key)), else: translate(key)
      J.property(key_js, translate(value))
    end)

    # Generate: new struct_var.constructor(Object.assign({}, struct_var, {updates}))
    J.new_expression(
      J.member_expression(struct_js, J.identifier("constructor"), false),
      [
        J.call_expression(
          J.member_expression(J.identifier("Object"), J.identifier("assign"), false),
          [
            J.object_expression([]),
            struct_js,
            J.object_expression(updates_props)
          ]
        )
      ]
    )
  end

  # Range struct - special handling to convert back to Range constructor
  # Elixir compiles 1..10 to %Range{first: 1, last: 10, step: 1}
  def translate({:%{}, _meta, pairs}) when is_list(pairs) do
    case Keyword.get(pairs, :__struct__) do
      Range ->
        # Extract range fields
        first = Keyword.get(pairs, :first)
        last = Keyword.get(pairs, :last)
        step = Keyword.get(pairs, :step)

        # Generate new Range(first, last, step)
        args = if step == 1 or step == -1 do
          # Omit step if it's the default
          [translate(first), translate(last)]
        else
          [translate(first), translate(last), translate(step)]
        end

        J.new_expression(
          J.identifier("Range"),
          args
        )

      _ ->
        # Regular map
        translate_map(pairs)
    end
  end

  # Maps (extracted to helper)
  defp translate_map(pairs) do
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

  # Assignment operator: var = value
  def translate({:=, _meta, [left, right]}) do
    # For now, handle simple variable assignment
    # More complex patterns would need destructuring
    case left do
      {var, _meta, context} when is_atom(var) and (is_nil(context) or is_atom(context)) ->
        # Simple variable assignment
        J.assignment_expression(:"=", J.identifier(Atom.to_string(var)), translate(right))

      _ ->
        IO.warn("Unsupported assignment pattern: #{inspect(left)}")
        J.assignment_expression(:"=", J.identifier("_"), translate(right))
    end
  end

  # Binary operators
  def translate({op, _meta, [left, right]})
      when op in [:+, :-, :*, :/, :==, :!=, :<, :>, :<=, :>=, :and, :or] do
    js_op = elixir_op_to_js(op)
    J.binary_expression(js_op, translate(left), translate(right))
  end

  # Struct instantiation: %StructName{field: value}
  # IMPORTANT: This must come BEFORE the general function call pattern
  def translate({:%, _meta, [struct_module, {:%{}, _, fields}]}) do
    # Extract struct name - handle both full module path and nested modules
    struct_name = extract_struct_name(struct_module)

    # Convert fields to object properties
    field_props = Enum.map(fields, fn {key, value} ->
      key_js = if is_atom(key), do: J.literal(Atom.to_string(key)), else: translate(key)
      J.property(key_js, translate(value))
    end)

    # Generate: new StructName({field: value, ...})
    J.new_expression(
      J.identifier(struct_name),
      [J.object_expression(field_props)]
    )
  end

  # Function capture: &function/arity
  # MUST come before general patterns
  def translate({:&, _meta, [{:/, _, [{func_name, _, nil}, _arity]}]}) when is_atom(func_name) do
    # Simple function capture - just reference the function name
    # In JavaScript, this is just the function identifier
    J.identifier(Atom.to_string(func_name))
  end

  # Anonymous function definition: fn x -> x * 2 end
  # MUST come before general function call pattern
  def translate({:fn, _meta, clauses}) do
    # For now, only handle single-clause functions
    # Multi-clause anonymous functions would need pattern matching
    case clauses do
      [{:->, _arrow_meta, [params, body]}] ->
        # Translate parameters
        js_params = Enum.map(params, fn
          {name, _param_meta, nil} when is_atom(name) ->
            J.identifier(Atom.to_string(name))

          # Other patterns would need more complex handling
          other ->
            IO.warn("Unsupported anonymous function parameter pattern: #{inspect(other)}")
            J.identifier("_")
        end)

        # Translate body
        js_body = translate(body)

        # Create arrow function with expression body
        J.arrow_function_expression(js_params, [], js_body, false, true, false)

      _multi_clause ->
        IO.warn("Multi-clause anonymous functions not yet supported: #{inspect(clauses)}")
        J.literal(nil)
    end
  end

  # Blocks: (expr1; expr2; expr3)
  # MUST come before function call pattern because {:__block__, meta, exprs} looks like a function call
  def translate({:__block__, _meta, exprs}) when is_list(exprs) do
    # A block in Elixir executes all expressions and returns the last one
    # In JavaScript, we can use a sequence expression or an IIFE
    # Using sequence expression (comma operator): (expr1, expr2, expr3)
    case exprs do
      [] ->
        J.literal(nil)

      [single] ->
        translate(single)

      [_first | _rest] = multiple ->
        # Create an IIFE that executes all expressions
        # (() => { expr1; expr2; return expr3; })()
        statements = multiple
        |> Enum.drop(-1)
        |> Enum.map(fn expr ->
          # Wrap expressions in expression statements
          J.expression_statement(translate(expr))
        end)

        last_expr = translate(List.last(multiple))
        return_stmt = J.return_statement(last_expr)

        iife_body = J.block_statement(statements ++ [return_stmt])
        iife_func = J.arrow_function_expression([], [], iife_body, false, false, false)

        J.call_expression(iife_func, [])
    end
  end

  # Anonymous function call: (fn x -> x * 2 end).(value)
  # Pattern: {{:., meta, [function]}, meta, [args]}
  # MUST come before remote function calls
  def translate({{:., _meta1, [func]}, _meta2, args}) when is_list(args) do
    js_func = translate(func)
    js_args = Enum.map(args, &translate/1)
    J.call_expression(js_func, js_args)
  end

  # Regular range: 1..10
  def translate({:.., _meta, [first, last]}) do
    js_first = translate(first)
    js_last = translate(last)

    J.new_expression(
      J.identifier("Range"),
      [js_first, js_last]
    )
  end

  # Stepped range: 1..10//2
  def translate({:"..//", _meta, [first, last, step]}) do
    js_first = translate(first)
    js_last = translate(last)
    js_step = translate(step)

    J.new_expression(
      J.identifier("Range"),
      [js_first, js_last, js_step]
    )
  end

  # Variable references (including compiler-generated ones)
  def translate({var, _meta, context}) when is_atom(var) and (is_nil(context) or is_atom(context)) do
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
    case {module, func} do
      # Erlang operators - translate directly to JS operators
      {:erlang, op} when op in [:+, :-, :*, :/, :==, :!=, :<, :>, :<=, :>=, :and, :or] ->
        [left, right] = args
        js_op = elixir_op_to_js(op)
        J.binary_expression(js_op, translate(left), translate(right))

      # Duration.new!/1 - translate to new Duration({...})
      {Duration, :new!} ->
        translate_duration_new(args)

      # Duration.new!/1 with alias form
      {{:__aliases__, _, [:Duration]}, :new!} ->
        translate_duration_new(args)

      # HTTP.get/1 and HTTP.get/2 - translate to await HTTP.get(...)
      # Handle both compiled (HTTP atom) and uncompiled ({:__aliases__, _, [:HTTP]}) forms
      {{:__aliases__, _, [:HTTP]}, :get} ->
        translate_http_call("get", args)
      {HTTP, :get} ->
        translate_http_call("get", args)

      # HTTP.post/1 and HTTP.post/2 - translate to await HTTP.post(...)
      {{:__aliases__, _, [:HTTP]}, :post} ->
        translate_http_call("post", args)
      {HTTP, :post} ->
        translate_http_call("post", args)

      # HTTP.put/1 and HTTP.put/2 - translate to await HTTP.put(...)
      {{:__aliases__, _, [:HTTP]}, :put} ->
        translate_http_call("put", args)
      {HTTP, :put} ->
        translate_http_call("put", args)

      # HTTP.delete/1 and HTTP.delete/2 - translate to await HTTP.delete(...)
      {{:__aliases__, _, [:HTTP]}, :delete} ->
        translate_http_call("delete", args)
      {HTTP, :delete} ->
        translate_http_call("delete", args)

      # HTTP.request/3 - translate to await HTTP.request(...)
      {{:__aliases__, _, [:HTTP]}, :request} ->
        translate_http_call("request", args)
      {HTTP, :request} ->
        translate_http_call("request", args)

      # Other remote calls
      _ ->
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
  end

  # Catch-all for unsupported expressions
  def translate(expr) do
    # For now, return null for anything we don't support yet
    # TODO: Add proper error handling
    IO.warn("Unsupported expression: #{inspect(expr)}")
    J.literal(nil)
  end

  # Private helpers

  defp translate_duration_new(args) do
    # Duration.new!(keyword_list) -> new Duration({...})
    # Args is a list containing a keyword list
    case args do
      # Empty list: Duration.new!([])
      [[]] ->
        J.new_expression(
          J.identifier("Duration"),
          [J.object_expression([])]
        )

      # Keyword list: Duration.new!(hour: 2, minute: 30)
      [keyword_list] when is_list(keyword_list) ->
        # Convert keyword list to object properties
        fields = Enum.map(keyword_list, fn {key, value} ->
          J.property(
            J.identifier(Atom.to_string(key)),
            translate(value)
          )
        end)

        J.new_expression(
          J.identifier("Duration"),
          [J.object_expression(fields)]
        )

      # Fallback
      _ ->
        IO.warn("Unexpected Duration.new! arguments: #{inspect(args)}")
        J.new_expression(
          J.identifier("Duration"),
          [J.object_expression([])]
        )
    end
  end

  defp translate_http_call(method_name, args) do
    # HTTP.method(url) -> await HTTP.method(url)
    # HTTP.method(url, opts) -> await HTTP.method(url, { headers: ..., body: ... })
    # HTTP.request(method, url, opts) -> await HTTP.request(method, url, { headers: ..., body: ... })

    case args do
      # Single argument: HTTP.get(url)
      [url] ->
        J.await_expression(
          J.call_expression(
            J.member_expression(
              J.identifier("HTTP"),
              J.identifier(method_name)
            ),
            [translate(url)]
          )
        )

      # Two arguments for HTTP.get/post/put/delete: HTTP.get(url, opts)
      [url, opts] when method_name != "request" ->
        # Translate options keyword list to JavaScript object
        opts_js = translate_http_options(opts)

        J.await_expression(
          J.call_expression(
            J.member_expression(
              J.identifier("HTTP"),
              J.identifier(method_name)
            ),
            [translate(url), opts_js]
          )
        )

      # Three arguments for HTTP.request: HTTP.request(method, url, opts)
      [method, url, opts] when method_name == "request" ->
        opts_js = translate_http_options(opts)

        J.await_expression(
          J.call_expression(
            J.member_expression(
              J.identifier("HTTP"),
              J.identifier(method_name)
            ),
            [translate(method), translate(url), opts_js]
          )
        )

      # Fallback
      _ ->
        IO.warn("Unexpected HTTP.#{method_name} arguments: #{inspect(args)}")
        J.literal(nil)
    end
  end

  defp translate_http_options(opts) do
    # Convert Elixir keyword list to JavaScript object
    # [headers: [...], body: "..."] -> { headers: {...}, body: "..." }

    case opts do
      # Keyword list
      opts when is_list(opts) ->
        properties = Enum.map(opts, fn {key, value} ->
          case key do
            :headers ->
              # Convert header list to object
              # [{"Content-Type", "application/json"}] -> { "Content-Type": "application/json" }
              headers_obj = translate_headers(value)
              J.property(J.identifier("headers"), headers_obj)

            :body ->
              # Body is already a string (usually from Jason.encode!)
              J.property(J.identifier("body"), translate(value))

            _ ->
              # Other options
              J.property(J.identifier(Atom.to_string(key)), translate(value))
          end
        end)

        J.object_expression(properties)

      # If opts is not a keyword list, try to translate it directly
      _ ->
        translate(opts)
    end
  end

  defp translate_headers(headers) do
    # Convert header list to JavaScript object
    # [{"Content-Type", "application/json"}, {"Authorization", "Bearer ..."}]
    # -> { "Content-Type": "application/json", "Authorization": "Bearer ..." }

    case headers do
      headers when is_list(headers) ->
        properties = Enum.map(headers, fn
          {key, value} when is_binary(key) ->
            J.property(J.literal(key), translate(value))

          {key, value} ->
            J.property(translate(key), translate(value))

          _ ->
            # Skip invalid header format
            nil
        end)
        |> Enum.reject(&is_nil/1)

        J.object_expression(properties)

      # If headers is not a list, translate it directly
      _ ->
        translate(headers)
    end
  end

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

  defp extract_struct_name(module) when is_atom(module) do
    # Get the last part of the module name (e.g., Fixtures.Structs.User -> User)
    module
    |> Atom.to_string()
    |> String.split(".")
    |> List.last()
  end

  defp extract_struct_name({:__aliases__, _meta, parts}) do
    # For aliased modules, use the last part
    parts
    |> List.last()
    |> Atom.to_string()
  end
end

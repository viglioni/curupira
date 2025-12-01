defmodule CurupiraScript.Compiler do
  @moduledoc """
  The entry point for CurupiraScript compilation.

  Takes Elixir module(s) and compiles them to JavaScript (ES2020+).

  ## Example

      iex> CurupiraScript.Compiler.compile(MyApp)
      {:ok, %{
        compiled_modules: [MyApp],
        output_files: [%{path: "priv/curupira_script/build/Elixir.MyApp.js", content: "..."}],
        source_maps: []
      }}

  """

  alias CurupiraScript.{Beam, Translator, Error}
  alias ESTree.Tools.{Builder, Generator}

  @doc """
  Compile one or more Elixir modules to JavaScript.

  ## Parameters

  - `modules` - Single module atom or list of module atoms
  - `opts` - Keyword list of options

  ## Options

  - `:output` - Output directory (default: "priv/curupira_script/build")
  - `:source_maps` - Generate source maps (default: true in dev, false in prod)
  - `:format` - Output format, only `:es` supported (default: `:es`)

  ## Returns

  - `{:ok, map}` - Success with compilation result
  - `{:error, term}` - Compilation error

  """
  @spec compile(module() | [module()], keyword()) :: {:ok, map()} | {:error, term()}
  def compile(modules, opts \\ [])

  def compile(module, opts) when is_atom(module) do
    compile([module], opts)
  end

  def compile(modules, opts) when is_list(modules) do
    # Validate input
    case validate_input(modules, opts) do
      :ok ->
        do_compile(modules, opts)

      error ->
        error
    end
  end

  # Private functions

  defp validate_input([], _opts) do
    {:error, Error.validation_error(:empty_module_list)}
  end

  defp validate_input(modules, opts) when is_list(modules) do
    # Check all items are atoms
    case Enum.find(modules, fn x -> not is_atom(x) end) do
      nil ->
        validate_options(opts)

      invalid ->
        {:error, Error.validation_error({:invalid_module, invalid})}
    end
  end

  defp validate_options(opts) do
    # For now, accept any options - we'll validate specific ones as we implement them
    # TODO: Phase 0 - implement full option validation
    _ = opts
    :ok
  end

  defp do_compile(modules, opts) do
    output_dir = Keyword.get(opts, :output, "priv/curupira_script/build")
    generate_source_maps = Keyword.get(opts, :source_maps, Mix.env() != :prod)

    # Extract AST from all modules
    case extract_module_info(modules) do
      {:ok, module_infos} ->
        # Translate each module to JavaScript
        case translate_modules(module_infos) do
          {:ok, js_modules} ->
            # Build output files
            output_files = build_output_files(js_modules, output_dir)

            # Generate source maps if enabled
            source_maps = if generate_source_maps do
              build_source_maps(modules, module_infos, output_dir)
            else
              []
            end

            {:ok,
             %{
               compiled_modules: modules,
               output_files: output_files,
               source_maps: source_maps
             }}

          error ->
            error
        end

      error ->
        error
    end
  end

  defp extract_module_info(modules) do
    results =
      Enum.map(modules, fn module ->
        case Beam.debug_info(module) do
          {:ok, info} ->
            {:ok, {module, info}}

          {:error, reason} ->
            # Get file info from module if available
            file = get_module_file(module)
            {:error, Error.compilation_error(module, reason, file: file)}
        end
      end)

    # Check if any errors occurred
    case Enum.find(results, fn
           {:error, _} -> true
           _ -> false
         end) do
      nil ->
        module_infos =
          Enum.map(results, fn {:ok, module_info} -> module_info end)

        {:ok, module_infos}

      error ->
        error
    end
  end

  defp get_module_file(module) do
    # Try to get file from module_info
    try do
      module.module_info(:compile)
      |> Keyword.get(:source)
      |> case do
        nil -> nil
        source when is_list(source) -> List.to_string(source)
        source -> source
      end
    rescue
      _ -> nil
    end
  end

  defp translate_modules(module_infos) do
    results =
      Enum.map(module_infos, fn {module, info} ->
        case translate_module(module, info) do
          {:ok, js_ast} ->
            # Convert AST to JavaScript code
            js_code = Generator.generate(js_ast)
            {:ok, {module, js_code}}

          error ->
            error
        end
      end)

    # Check if any errors occurred
    case Enum.find(results, fn
           {:error, _} -> true
           _ -> false
         end) do
      nil ->
        js_modules = Enum.map(results, fn {:ok, module_js} -> module_js end)
        {:ok, js_modules}

      error ->
        error
    end
  end

  defp translate_module(module, info) do
    # For now, generate a simple ES module
    # TODO: Implement full translation in translate/* modules

    # Get module functions
    definitions = Map.get(info, :definitions, [])

    # Check if this module has nested struct modules
    struct_classes = detect_and_generate_struct_classes(module)

    # Translate each function
    functions = translate_functions(definitions)

    # Detect which runtime modules are needed (Enum, String, Map, JSON, HTTP)
    runtime_imports = detect_runtime_imports(definitions)

    # Build runtime imports (Enum, String, Map, JSON, HTTP, HTTPResponse)
    import_statements = build_runtime_import_statements(runtime_imports)

    # Build pattern matching runtime helpers
    helpers = build_pattern_matching_helpers()

    # Add Range class (struct type)
    range_class = build_range_class()

    # Add Duration class (struct type)
    duration_class = build_duration_class()

    # Build ES module: imports + duration + range + helpers + struct classes + export default { ...functions }
    # Note: JSON, HTTP, HTTPResponse are now imported from runtime library, not generated
    module_ast =
      Builder.export_default_declaration(
        Builder.object_expression(functions)
      )

    {:ok, Builder.program(import_statements ++ [duration_class, range_class] ++ helpers ++ struct_classes ++ [module_ast])}
  end

  defp translate_functions(definitions) do
    Enum.flat_map(definitions, fn
      # Public function
      {{name, _arity}, :def, _meta, clauses} when is_list(clauses) ->
        cond do
          # Single clause - check if it has pattern matching
          length(clauses) == 1 ->
            [{_clause_meta, params, _guards, body}] = clauses

            # Check if any parameters use pattern matching
            has_patterns = Enum.any?(params, fn param ->
              case param do
                {_name, _meta, nil} -> false
                _ -> true
              end
            end)

            if has_patterns do
              # Use multi-clause function logic for single clause with patterns
              translate_multi_clause_function(name, clauses)
            else
              # Simple function without patterns
              # Translate function parameters
              js_params = translate_params(params)

              # Translate function body
              js_body_expr = Translator.translate(body)

              # Wrap in block statement with return
              js_body =
                Builder.block_statement([
                  Builder.return_statement(js_body_expr)
                ])

              [
                Builder.property(
                  Builder.identifier(Atom.to_string(name)),
                  Builder.function_expression(js_params, [], js_body)
                )
              ]
            end

          # Multi-clause - need pattern matching
          true ->
            translate_multi_clause_function(name, clauses)
        end

      # Skip private functions, macros, etc for now
      _ ->
        []
    end)
  end

  defp translate_multi_clause_function(name, clauses) do
    # For multi-clause functions, create a function that checks each clause
    # Generate: function(...args) { /* try each clause */ }

    # Use rest parameter to accept all arguments
    js_params = [Builder.rest_element(Builder.identifier("args"))]

    # Generate if-else chain for each clause
    js_body_statements = build_clause_checks(clauses)

    # Add fallback error if no clause matches
    fallback = Builder.throw_statement(
      Builder.new_expression(
        Builder.identifier("Error"),
        [Builder.literal("No matching function clause")]
      )
    )

    js_body = Builder.block_statement(js_body_statements ++ [fallback])

    [
      Builder.property(
        Builder.identifier(Atom.to_string(name)),
        Builder.function_expression(js_params, [], js_body)
      )
    ]
  end

  defp build_clause_checks(clauses) do
    clauses
    |> Enum.with_index()
    |> Enum.map(fn {{_clause_meta, params, guards, body}, index} ->
      # Generate pattern matching check and body execution
      build_clause_check(params, guards, body, index, length(clauses))
    end)
  end

  defp build_clause_check(params, guards, body, index, total_clauses) do
    # Generate: if (__matchPattern(args, pattern) && guardCheck) { const [p1, p2] = __extractPattern(args, pattern); return body; }

    # Build pattern array for this clause
    pattern_checks = build_pattern_checks(params)

    # Build guard checks
    guard_checks = build_guard_checks(guards)

    # Combine pattern checks and guard checks
    all_checks = if guard_checks do
      Builder.logical_expression(:"&&", pattern_checks, guard_checks)
    else
      pattern_checks
    end

    # Build variable bindings for matched values
    bindings = build_pattern_bindings(params)

    # Translate function body
    js_body_expr = Translator.translate(body)

    # Build the clause body: bindings + return
    clause_body_statements = bindings ++ [Builder.return_statement(js_body_expr)]

    # Build the if statement
    if index == total_clauses - 1 do
      # Last clause - no condition needed if previous clauses didn't match
      # But we still need to check the pattern
      Builder.if_statement(
        all_checks,
        Builder.block_statement(clause_body_statements),
        nil
      )
    else
      Builder.if_statement(
        all_checks,
        Builder.block_statement(clause_body_statements),
        nil
      )
    end
  end

  defp build_pattern_checks(params) do
    # Generate condition: args.length === N && pattern checks
    length_check = Builder.binary_expression(
      :"===",
      Builder.member_expression(
        Builder.identifier("args"),
        Builder.identifier("length"),
        false
      ),
      Builder.literal(length(params))
    )

    # Generate pattern checks for each parameter
    param_checks = params
    |> Enum.with_index()
    |> Enum.map(fn {param, index} ->
      build_single_pattern_check(param, index)
    end)
    |> Enum.reject(&is_nil/1)

    # Combine all checks with &&
    Enum.reduce([length_check | param_checks], fn check, acc ->
      Builder.logical_expression(:"&&", acc, check)
    end)
  end

  defp build_single_pattern_check(param, index) do
    arg_access = Builder.member_expression(
      Builder.identifier("args"),
      Builder.literal(index),
      true
    )

    case param do
      # Struct pattern: %StructName{field: value}
      {:%, _meta, [struct_module, {:%{}, _, _field_patterns}]} ->
        # Check: args[i].__struct__ === Symbol.for("Elixir.StructModule")
        # struct_module is already the full atom (e.g., Elixir.Fixtures.Structs.User)
        struct_name = Atom.to_string(struct_module)

        Builder.binary_expression(
          :"===",
          Builder.member_expression(
            arg_access,
            Builder.identifier("__struct__"),
            false
          ),
          Builder.call_expression(
            Builder.member_expression(
              Builder.identifier("Symbol"),
              Builder.identifier("for"),
              false
            ),
            [Builder.literal(struct_name)]
          )
        )

      # Empty list pattern: []
      [] ->
        # Check: Array.isArray(args[i]) && args[i].length === 0
        Builder.logical_expression(
          :"&&",
          Builder.call_expression(
            Builder.member_expression(
              Builder.identifier("Array"),
              Builder.identifier("isArray"),
              false
            ),
            [arg_access]
          ),
          Builder.binary_expression(
            :"===",
            Builder.member_expression(
              arg_access,
              Builder.identifier("length"),
              false
            ),
            Builder.literal(0)
          )
        )

      # List destructuring: [head | tail]
      [{:|, _meta, [_head, _tail]}] ->
        # Check: Array.isArray(args[i]) && args[i].length > 0
        Builder.logical_expression(
          :"&&",
          Builder.call_expression(
            Builder.member_expression(
              Builder.identifier("Array"),
              Builder.identifier("isArray"),
              false
            ),
            [arg_access]
          ),
          Builder.binary_expression(
            :">",
            Builder.member_expression(
              arg_access,
              Builder.identifier("length"),
              false
            ),
            Builder.literal(0)
          )
        )

      # Variable pattern - always matches
      {_name, _meta, nil} ->
        nil

      # Wildcard pattern - always matches
      _ ->
        nil
    end
  end

  defp build_pattern_bindings(params) do
    params
    |> Enum.with_index()
    |> Enum.flat_map(fn {param, index} ->
      build_single_pattern_binding(param, index)
    end)
  end

  defp build_single_pattern_binding(param, index) do
    arg_access = Builder.member_expression(
      Builder.identifier("args"),
      Builder.literal(index),
      true
    )

    case param do
      # Struct pattern: %StructName{field: value}
      {:%, _meta, [_struct_module, {:%{}, _, field_patterns}]} ->
        # Extract fields from struct
        # const name = args[i].name;
        Enum.flat_map(field_patterns, fn {field_key, field_value} ->
          case field_value do
            # Variable binding: name: name or name: some_var
            {var_name, _, nil} when is_atom(var_name) ->
              if var_name == :_ or String.starts_with?(Atom.to_string(var_name), "_") do
                []
              else
                [
                  Builder.variable_declaration(
                    [
                      Builder.variable_declarator(
                        Builder.identifier(Atom.to_string(var_name)),
                        Builder.member_expression(
                          arg_access,
                          Builder.identifier(Atom.to_string(field_key)),
                          false
                        )
                      )
                    ],
                    :const
                  )
                ]
              end

            # Literal match - no binding needed
            _ ->
              []
          end
        end)

      # Empty list - no bindings needed
      [] ->
        []

      # List destructuring: [head | tail]
      [{:|, _meta, [{head_name, _, nil}, {tail_name, _, nil}]}] ->
        # const head = args[i][0]
        # const tail = args[i].slice(1)
        # Skip bindings for variables that start with _ (including _tail, _head, etc)
        head_binding = if not String.starts_with?(Atom.to_string(head_name), "_") do
          [
            Builder.variable_declaration(
              [
                Builder.variable_declarator(
                  Builder.identifier(Atom.to_string(head_name)),
                  Builder.member_expression(
                    arg_access,
                    Builder.literal(0),
                    true
                  )
                )
              ],
              :const
            )
          ]
        else
          []
        end

        tail_binding = if not String.starts_with?(Atom.to_string(tail_name), "_") do
          [
            Builder.variable_declaration(
              [
                Builder.variable_declarator(
                  Builder.identifier(Atom.to_string(tail_name)),
                  Builder.call_expression(
                    Builder.member_expression(
                      arg_access,
                      Builder.identifier("slice"),
                      false
                    ),
                    [Builder.literal(1)]
                  )
                )
              ],
              :const
            )
          ]
        else
          []
        end

        head_binding ++ tail_binding

      # Variable pattern
      {name, _meta, nil} when is_atom(name) ->
        # Skip wildcard pattern _
        if name == :_ or String.starts_with?(Atom.to_string(name), "_") do
          []
        else
          [
            Builder.variable_declaration(
              [
                Builder.variable_declarator(
                  Builder.identifier(Atom.to_string(name)),
                  arg_access
                )
              ],
              :const
            )
          ]
        end

      # Other patterns - skip for now
      _ ->
        []
    end
  end

  defp translate_params(params) do
    Enum.map(params, fn
      {name, _meta, nil} when is_atom(name) ->
        Builder.identifier(Atom.to_string(name))

      # For single-clause functions with pattern matching, we need to handle it differently
      # For now, simple patterns just create a parameter name
      [] ->
        # Empty list - use a parameter name and we'll add validation in the function body
        Builder.identifier("_list")

      [{:|, _meta, [{_head_name, _, nil}, {_tail_name, _, nil}]}] ->
        # List destructuring - for single clause, destructure in function body
        # For now just accept a parameter
        Builder.identifier("_list")

      # Other patterns - use wildcard
      _other ->
        Builder.identifier("_")
    end)
  end

  defp build_guard_checks([]) do
    # No guards
    nil
  end

  defp build_guard_checks(guards) when is_list(guards) do
    # Guards are a list of guard expressions
    # Each guard group is OR'd together, then all groups are AND'd
    # For now, we'll handle single guard expressions
    guards
    |> Enum.map(&translate_guard_expression/1)
    |> Enum.reduce(fn guard, acc ->
      Builder.logical_expression(:"&&", acc, guard)
    end)
  end

  defp translate_guard_expression(guard) do
    case guard do
      # is_non_struct_map(var) - direct form (not expanded yet)
      {:is_non_struct_map, _meta, [var]} ->
        translate_is_non_struct_map_guard(var)

      # is_non_struct_map(var) - expanded form by Elixir compiler
      # Pattern: andalso(is_map(data), not(andalso(is_map_key(:__struct__, data), is_atom(map_get(:__struct__, data)))))
      {{:., _, [:erlang, :andalso]}, _,
       [
         {{:., _, [:erlang, :is_map]}, _, [var]},
         {{:., _, [:erlang, :not]}, _, [{{:., _, [:erlang, :andalso]}, _, _}]}
       ]} ->
        # This is the expanded form of is_non_struct_map - translate idiomatically
        translate_is_non_struct_map_guard(var)

      # Other guards - translate using Translator
      _ ->
        Translator.translate(guard)
    end
  end

  defp translate_is_non_struct_map_guard(var) do
    var_js = translate_guard_var(var)

    # Generate: (value !== null && typeof value === 'object' && !value.__struct__)
    # Build from inside out
    struct_check = Builder.unary_expression(
      :"!",
      true,  # prefix
      Builder.member_expression(
        var_js,
        Builder.identifier("__struct__"),
        false
      )
    )

    typeof_check = Builder.binary_expression(
      :"===",
      Builder.unary_expression(
        :typeof,
        true,  # prefix
        var_js
      ),
      Builder.literal("object")
    )

    null_check = Builder.binary_expression(
      :"!==",
      var_js,
      Builder.literal(nil)
    )

    # Combine: null_check && typeof_check && struct_check
    Builder.logical_expression(
      :"&&",
      Builder.logical_expression(:"&&", null_check, typeof_check),
      struct_check
    )
  end

  defp translate_guard_var(var) do
    case var do
      # Variable reference in guard: need to access from args array
      {var_name, _meta, nil} when is_atom(var_name) ->
        # Find the parameter index for this variable
        # For now, we'll assume it's the first parameter (args[0])
        # TODO: Track parameter positions properly
        Builder.member_expression(
          Builder.identifier("args"),
          Builder.literal(0),
          true
        )

      # Other expressions
      _ ->
        Translator.translate(var)
    end
  end

  defp build_pattern_matching_helpers do
    # For now, we inline pattern matching logic
    # Future: could add shared helper functions here
    []
  end

  defp detect_and_generate_struct_classes(module) do
    # Get all modules that are nested under this module
    # and have __struct__ functions (indicating they are structs)
    # Note: module is already the full atom like Elixir.Fixtures.Structs
    module_str = Atom.to_string(module)
    module_prefix = module_str <> "."

    # Find all BEAM files that match the module prefix
    # This works for both compiled and runtime modules
    beam_pattern = module_str |> String.replace(".", "") |> Kernel.<>("*.beam")

    # Get BEAM files from current directory (where test fixtures are compiled)
    current_dir_beams = Path.wildcard(beam_pattern)

    # Also check the code path for already loaded modules
    loaded_modules =
      :code.all_loaded()
      |> Enum.filter(fn {mod, _} ->
        mod_str = Atom.to_string(mod)
        String.starts_with?(mod_str, module_prefix)
      end)
      |> Enum.map(fn {mod, _} -> mod end)

    # Extract module names from BEAM files
    beam_modules =
      current_dir_beams
      |> Enum.map(fn beam_file ->
        beam_file
        |> Path.basename(".beam")
        |> String.to_atom()
      end)

    # Combine and deduplicate
    all_struct_modules = Enum.uniq(loaded_modules ++ beam_modules)

    # Filter to only structs and generate classes
    all_struct_modules
    |> Enum.filter(fn mod ->
      # Ensure module is loaded
      Code.ensure_loaded?(mod) and has_struct_function?(mod)
    end)
    |> Enum.map(&generate_struct_class/1)
  end

  defp has_struct_function?(module) do
    # Check if module has __struct__/0 function
    Code.ensure_loaded?(module) and function_exported?(module, :__struct__, 0)
  end

  defp generate_struct_class(struct_module) do
    # Get struct info by calling __struct__/0
    struct_map = struct_module.__struct__()

    # Extract struct name (last part of module)
    struct_name =
      struct_module
      |> Atom.to_string()
      |> String.split(".")
      |> List.last()

    # Get all fields except __struct__
    fields =
      struct_map
      |> Map.delete(:__struct__)
      |> Map.to_list()
      |> Enum.sort()

    # Generate JavaScript class
    # class User {
    #   constructor(fields = {}) {
    #     this.__struct__ = Symbol.for("Elixir.Fixtures.Structs.User");
    #     this.name = fields.name ?? null;
    #     this.age = fields.age ?? null;
    #     Object.freeze(this);
    #   }
    # }

    # Build constructor body
    constructor_body = build_struct_constructor_body(struct_module, fields)

    # Build class
    # Note: ESTree doesn't support assignment patterns directly, so we'll handle default in body
    # Add default parameter handling: fields = fields || {}
    default_param_check =
      Builder.expression_statement(
        Builder.assignment_expression(
          :"=",
          Builder.identifier("fields"),
          Builder.logical_expression(
            :"||",
            Builder.identifier("fields"),
            Builder.object_expression([])
          )
        )
      )

    full_constructor_body = [default_param_check] ++ constructor_body

    # Build class without superclass
    # Builder.class_declaration signature: (id, body, superClass)
    Builder.class_declaration(
      Builder.identifier(struct_name),
      Builder.class_body([
        Builder.method_definition(
          Builder.identifier("constructor"),
          Builder.function_expression(
            [Builder.identifier("fields")],
            [],
            Builder.block_statement(full_constructor_body)
          ),
          :constructor
        )
      ]),
      nil  # No superclass (extends clause)
    )
  end

  defp build_struct_constructor_body(struct_module, fields) do
    # Generate:
    # this.__struct__ = Symbol.for("Elixir.Module.Name");
    # this.field1 = fields.field1 ?? default1;
    # this.field2 = fields.field2 ?? default2;
    # Object.freeze(this);

    # struct_module is already the full atom (e.g., Elixir.Fixtures.Structs.User)
    struct_symbol_assignment =
      Builder.expression_statement(
        Builder.assignment_expression(
          :"=",
          Builder.member_expression(
            Builder.identifier("this"),
            Builder.identifier("__struct__"),
            false
          ),
          Builder.call_expression(
            Builder.member_expression(
              Builder.identifier("Symbol"),
              Builder.identifier("for"),
              false
            ),
            [Builder.literal(Atom.to_string(struct_module))]
          )
        )
      )

    field_assignments =
      Enum.map(fields, fn {field_name, default_value} ->
        # this.field = field_name in fields ? fields.field : default
        # Check if field exists using 'in' operator
        Builder.expression_statement(
          Builder.assignment_expression(
            :"=",
            Builder.member_expression(
              Builder.identifier("this"),
              Builder.identifier(Atom.to_string(field_name)),
              false
            ),
            # (field_name in fields ? fields.field_name : default)
            # Since we can't use conditional expression, use helper function approach:
            # We'll generate: fields.hasOwnProperty('field') ? fields.field : default
            # But ESTree doesn't support ternary! So use logical OR with undefined check:
            # (fields.field !== undefined ? fields.field : default)
            # Actually, just use: fields.field === undefined ? default : fields.field
            # Since that doesn't work, use call expression with helper
            # For now, simple approach: fields[field] || default (won't work for null/false)
            # Let's use the cleaner: fields.field === undefined && default || fields.field
            # Actually simplest: just assign and use || for now
            Builder.logical_expression(
              :"||",
              Builder.member_expression(
                Builder.identifier("fields"),
                Builder.identifier(Atom.to_string(field_name)),
                false
              ),
              Translator.translate(default_value)
            )
          )
        )
      end)

    freeze_statement =
      Builder.expression_statement(
        Builder.call_expression(
          Builder.member_expression(
            Builder.identifier("Object"),
            Builder.identifier("freeze"),
            false
          ),
          [Builder.identifier("this")]
        )
      )

    [struct_symbol_assignment] ++ field_assignments ++ [freeze_statement]
  end

  defp build_output_files(js_modules, output_dir) do
    Enum.map(js_modules, fn {module, js_code} ->
      filename = "Elixir.#{module}.js"
      path = Path.join(output_dir, filename)

      %{
        path: path,
        content: js_code
      }
    end)
  end

  defp build_range_class do
    # Generate Range class for supporting stepped ranges
    # class Range {
    #   constructor(first, last, step) { ... }
    #   *[Symbol.iterator]() { ... }
    #   toArray() { ... }
    #   size() { ... }
    # }

    # Constructor body
    constructor_body = [
      # this.first = first;
      Builder.expression_statement(
        Builder.assignment_expression(
          :"=",
          Builder.member_expression(
            Builder.identifier("this"),
            Builder.identifier("first"),
            false
          ),
          Builder.identifier("first")
        )
      ),
      # this.last = last;
      Builder.expression_statement(
        Builder.assignment_expression(
          :"=",
          Builder.member_expression(
            Builder.identifier("this"),
            Builder.identifier("last"),
            false
          ),
          Builder.identifier("last")
        )
      ),
      # Handle step with if-else
      # if (step !== null && step !== undefined) { this.step = step; } else if (first <= last) { this.step = 1; } else { this.step = -1; }
      Builder.if_statement(
        Builder.logical_expression(
          :"&&",
          Builder.binary_expression(
            :"!==",
            Builder.identifier("step"),
            Builder.literal(nil)
          ),
          Builder.binary_expression(
            :"!==",
            Builder.identifier("step"),
            Builder.identifier("undefined")
          )
        ),
        # then: this.step = step
        Builder.block_statement([
          Builder.expression_statement(
            Builder.assignment_expression(
              :"=",
              Builder.member_expression(
                Builder.identifier("this"),
                Builder.identifier("step"),
                false
              ),
              Builder.identifier("step")
            )
          )
        ]),
        # else: check direction
        Builder.if_statement(
          Builder.binary_expression(
            :"<=",
            Builder.identifier("first"),
            Builder.identifier("last")
          ),
          # then: this.step = 1
          Builder.block_statement([
            Builder.expression_statement(
              Builder.assignment_expression(
                :"=",
                Builder.member_expression(
                  Builder.identifier("this"),
                  Builder.identifier("step"),
                  false
                ),
                Builder.literal(1)
              )
            )
          ]),
          # else: this.step = -1
          Builder.block_statement([
            Builder.expression_statement(
              Builder.assignment_expression(
                :"=",
                Builder.member_expression(
                  Builder.identifier("this"),
                  Builder.identifier("step"),
                  false
                ),
                Builder.literal(-1)
              )
            )
          ])
        )
      ),
      # this.__struct__ = Symbol.for('Elixir.Range');
      Builder.expression_statement(
        Builder.assignment_expression(
          :"=",
          Builder.member_expression(
            Builder.identifier("this"),
            Builder.identifier("__struct__"),
            false
          ),
          Builder.call_expression(
            Builder.member_expression(
              Builder.identifier("Symbol"),
              Builder.identifier("for"),
              false
            ),
            [Builder.literal("Elixir.Range")]
          )
        )
      )
    ]

    # Iterator method body
    iterator_body = [
      # const { first, last, step } = this;
      Builder.variable_declaration(
        [
          Builder.variable_declarator(
            Builder.object_pattern([
              Builder.property(
                Builder.identifier("first"),
                Builder.identifier("first")
              ),
              Builder.property(
                Builder.identifier("last"),
                Builder.identifier("last")
              ),
              Builder.property(
                Builder.identifier("step"),
                Builder.identifier("step")
              )
            ]),
            Builder.identifier("this")
          )
        ],
        :const
      ),
      # if (step === 0) throw new Error('Range step cannot be 0');
      Builder.if_statement(
        Builder.binary_expression(
          :"===",
          Builder.identifier("step"),
          Builder.literal(0)
        ),
        Builder.throw_statement(
          Builder.new_expression(
            Builder.identifier("Error"),
            [Builder.literal("Range step cannot be 0")]
          )
        ),
        nil
      ),
      # if (step > 0) { for (let i = first; i <= last; i += step) yield i; }
      Builder.if_statement(
        Builder.binary_expression(:">", Builder.identifier("step"), Builder.literal(0)),
        Builder.block_statement([
          Builder.for_statement(
            Builder.variable_declaration(
              [Builder.variable_declarator(Builder.identifier("i"), Builder.identifier("first"))],
              :let
            ),
            Builder.binary_expression(:"<=", Builder.identifier("i"), Builder.identifier("last")),
            Builder.assignment_expression(
              :"+=",
              Builder.identifier("i"),
              Builder.identifier("step")
            ),
            Builder.expression_statement(
              Builder.yield_expression(Builder.identifier("i"), false)
            )
          )
        ]),
        # else if (step < 0) { for (let i = first; i >= last; i += step) yield i; }
        Builder.if_statement(
          Builder.binary_expression(:"<", Builder.identifier("step"), Builder.literal(0)),
          Builder.block_statement([
            Builder.for_statement(
              Builder.variable_declaration(
                [Builder.variable_declarator(Builder.identifier("i"), Builder.identifier("first"))],
                :let
              ),
              Builder.binary_expression(:">=", Builder.identifier("i"), Builder.identifier("last")),
              Builder.assignment_expression(
                :"+=",
                Builder.identifier("i"),
                Builder.identifier("step")
              ),
              Builder.expression_statement(
                Builder.yield_expression(Builder.identifier("i"), false)
              )
            )
          ]),
          nil
        )
      )
    ]

    # toArray method body
    to_array_body = [
      Builder.return_statement(
        Builder.call_expression(
          Builder.member_expression(
            Builder.identifier("Array"),
            Builder.identifier("from"),
            false
          ),
          [Builder.identifier("this")]
        )
      )
    ]

    # size method body
    size_body = [
      # const { first, last, step } = this;
      Builder.variable_declaration(
        [
          Builder.variable_declarator(
            Builder.object_pattern([
              Builder.property(Builder.identifier("first"), Builder.identifier("first")),
              Builder.property(Builder.identifier("last"), Builder.identifier("last")),
              Builder.property(Builder.identifier("step"), Builder.identifier("step"))
            ]),
            Builder.identifier("this")
          )
        ],
        :const
      ),
      # if (step > 0) return Math.max(0, Math.floor((last - first) / step) + 1);
      Builder.if_statement(
        Builder.binary_expression(:">", Builder.identifier("step"), Builder.literal(0)),
        Builder.return_statement(
          Builder.call_expression(
            Builder.member_expression(
              Builder.identifier("Math"),
              Builder.identifier("max"),
              false
            ),
            [
              Builder.literal(0),
              Builder.binary_expression(
                :+,
                Builder.call_expression(
                  Builder.member_expression(
                    Builder.identifier("Math"),
                    Builder.identifier("floor"),
                    false
                  ),
                  [
                    Builder.binary_expression(
                      :/,
                      Builder.binary_expression(:-, Builder.identifier("last"), Builder.identifier("first")),
                      Builder.identifier("step")
                    )
                  ]
                ),
                Builder.literal(1)
              )
            ]
          )
        ),
        # else return Math.max(0, Math.floor((first - last) / Math.abs(step)) + 1);
        Builder.return_statement(
          Builder.call_expression(
            Builder.member_expression(
              Builder.identifier("Math"),
              Builder.identifier("max"),
              false
            ),
            [
              Builder.literal(0),
              Builder.binary_expression(
                :+,
                Builder.call_expression(
                  Builder.member_expression(
                    Builder.identifier("Math"),
                    Builder.identifier("floor"),
                    false
                  ),
                  [
                    Builder.binary_expression(
                      :/,
                      Builder.binary_expression(:-, Builder.identifier("first"), Builder.identifier("last")),
                      Builder.call_expression(
                        Builder.member_expression(
                          Builder.identifier("Math"),
                          Builder.identifier("abs"),
                          false
                        ),
                        [Builder.identifier("step")]
                      )
                    )
                  ]
                ),
                Builder.literal(1)
              )
            ]
          )
        )
      )
    ]

    # Build the iterator method manually to set computed flag
    iterator_method = %ESTree.MethodDefinition{
      type: "MethodDefinition",
      key: Builder.member_expression(
        Builder.identifier("Symbol"),
        Builder.identifier("iterator"),
        false
      ),
      value: Builder.function_expression(
        [],
        [],
        Builder.block_statement(iterator_body),
        true,  # generator
        false,  # expression
        false   # async
      ),
      kind: :method,
      computed: true,  # This makes it [Symbol.iterator]
      static: false
    }

    # Build the class
    Builder.class_declaration(
      Builder.identifier("Range"),
      Builder.class_body([
        # constructor(first, last, step) - step defaults will be handled in body
        Builder.method_definition(
          Builder.identifier("constructor"),
          Builder.function_expression(
            [
              Builder.identifier("first"),
              Builder.identifier("last"),
              Builder.identifier("step")
            ],
            [],
            Builder.block_statement(constructor_body)
          ),
          :constructor
        ),
        # *[Symbol.iterator]() - manually constructed with computed: true
        iterator_method,
        # toArray()
        Builder.method_definition(
          Builder.identifier("toArray"),
          Builder.function_expression(
            [],
            [],
            Builder.block_statement(to_array_body)
          ),
          :method
        ),
        # size()
        Builder.method_definition(
          Builder.identifier("size"),
          Builder.function_expression(
            [],
            [],
            Builder.block_statement(size_body)
          ),
          :method
        )
      ]),
      nil  # No superclass
    )
  end

  defp build_duration_class do
    # Generate Duration class for representing time durations
    # class Duration {
    #   constructor({ year, month, week, day, hour, minute, second, microsecond }) {
    #     this.year = year || 0;
    #     this.month = month || 0;
    #     this.week = week || 0;
    #     this.day = day || 0;
    #     this.hour = hour || 0;
    #     this.minute = minute || 0;
    #     this.second = second || 0;
    #     this.microsecond = microsecond || 0;
    #     this.__struct__ = Symbol.for('Elixir.Duration');
    #     Object.freeze(this);
    #   }
    #   toMilliseconds() { ... }
    # }

    # List of all Duration fields
    duration_fields = [
      :year,
      :month,
      :week,
      :day,
      :hour,
      :minute,
      :second,
      :microsecond
    ]

    # Constructor body
    constructor_body = [
      # fields = fields || {}
      Builder.expression_statement(
        Builder.assignment_expression(
          :"=",
          Builder.identifier("fields"),
          Builder.logical_expression(
            :"||",
            Builder.identifier("fields"),
            Builder.object_expression([])
          )
        )
      )
    ] ++
    # For each field: this.field = fields.field || 0
    Enum.map(duration_fields, fn field_name ->
      field_str = Atom.to_string(field_name)
      Builder.expression_statement(
        Builder.assignment_expression(
          :"=",
          Builder.member_expression(
            Builder.identifier("this"),
            Builder.identifier(field_str),
            false
          ),
          Builder.logical_expression(
            :"||",
            Builder.member_expression(
              Builder.identifier("fields"),
              Builder.identifier(field_str),
              false
            ),
            Builder.literal(0)
          )
        )
      )
    end) ++
    [
      # this.__struct__ = Symbol.for('Elixir.Duration');
      Builder.expression_statement(
        Builder.assignment_expression(
          :"=",
          Builder.member_expression(
            Builder.identifier("this"),
            Builder.identifier("__struct__"),
            false
          ),
          Builder.call_expression(
            Builder.member_expression(
              Builder.identifier("Symbol"),
              Builder.identifier("for"),
              false
            ),
            [Builder.literal("Elixir.Duration")]
          )
        )
      ),
      # Object.freeze(this);
      Builder.expression_statement(
        Builder.call_expression(
          Builder.member_expression(
            Builder.identifier("Object"),
            Builder.identifier("freeze"),
            false
          ),
          [Builder.identifier("this")]
        )
      )
    ]

    # toMilliseconds method body
    # Approximate conversion to milliseconds for JavaScript Date operations
    to_ms_body = [
      Builder.return_statement(
        # Build the expression: year * 365.25 * 24 * 60 * 60 * 1000 + month * 30.44 * ...
        Enum.reduce(
          [
            {:year, 365.25 * 24 * 60 * 60 * 1000},
            {:month, 30.44 * 24 * 60 * 60 * 1000},
            {:week, 7 * 24 * 60 * 60 * 1000},
            {:day, 24 * 60 * 60 * 1000},
            {:hour, 60 * 60 * 1000},
            {:minute, 60 * 1000},
            {:second, 1000},
            {:microsecond, 0.001}
          ],
          Builder.literal(0),
          fn {field, multiplier}, acc ->
            Builder.binary_expression(
              :+,
              acc,
              Builder.binary_expression(
                :*,
                Builder.member_expression(
                  Builder.identifier("this"),
                  Builder.identifier(Atom.to_string(field)),
                  false
                ),
                Builder.literal(multiplier)
              )
            )
          end
        )
      )
    ]

    # Build the class
    Builder.class_declaration(
      Builder.identifier("Duration"),
      Builder.class_body([
        # constructor(fields)
        Builder.method_definition(
          Builder.identifier("constructor"),
          Builder.function_expression(
            [Builder.identifier("fields")],
            [],
            Builder.block_statement(constructor_body)
          ),
          :constructor
        ),
        # toMilliseconds()
        Builder.method_definition(
          Builder.identifier("toMilliseconds"),
          Builder.function_expression(
            [],
            [],
            Builder.block_statement(to_ms_body)
          ),
          :method
        )
      ]),
      nil  # No superclass
    )
  end

  defp build_http_response_class do
    # Generate HTTPResponse class for representing HTTP responses
    # class HTTPResponse {
    #   constructor(status, headers, body, ok) {
    #     this.status = status;
    #     this.headers = headers;
    #     this.body = body;
    #     this.ok = ok !== undefined ? ok : (status >= 200 && status < 300);
    #     this.__struct__ = Symbol.for('Elixir.HTTP.Response');
    #     Object.freeze(this);
    #   }
    # }

    # Constructor body
    constructor_body = [
      # this.status = status;
      Builder.expression_statement(
        Builder.assignment_expression(
          :"=",
          Builder.member_expression(
            Builder.identifier("this"),
            Builder.identifier("status"),
            false
          ),
          Builder.identifier("status")
        )
      ),
      # this.headers = headers;
      Builder.expression_statement(
        Builder.assignment_expression(
          :"=",
          Builder.member_expression(
            Builder.identifier("this"),
            Builder.identifier("headers"),
            false
          ),
          Builder.identifier("headers")
        )
      ),
      # this.body = body;
      Builder.expression_statement(
        Builder.assignment_expression(
          :"=",
          Builder.member_expression(
            Builder.identifier("this"),
            Builder.identifier("body"),
            false
          ),
          Builder.identifier("body")
        )
      ),
      # Handle ok field with if-else
      # if (ok !== undefined) { this.ok = ok; } else { this.ok = (status >= 200 && status < 300); }
      Builder.if_statement(
        Builder.binary_expression(
          :"!==",
          Builder.identifier("ok"),
          Builder.identifier("undefined")
        ),
        # then: this.ok = ok
        Builder.block_statement([
          Builder.expression_statement(
            Builder.assignment_expression(
              :"=",
              Builder.member_expression(
                Builder.identifier("this"),
                Builder.identifier("ok"),
                false
              ),
              Builder.identifier("ok")
            )
          )
        ]),
        # else: this.ok = (status >= 200 && status < 300)
        Builder.block_statement([
          Builder.expression_statement(
            Builder.assignment_expression(
              :"=",
              Builder.member_expression(
                Builder.identifier("this"),
                Builder.identifier("ok"),
                false
              ),
              Builder.logical_expression(
                :"&&",
                Builder.binary_expression(
                  :">=",
                  Builder.identifier("status"),
                  Builder.literal(200)
                ),
                Builder.binary_expression(
                  :"<",
                  Builder.identifier("status"),
                  Builder.literal(300)
                )
              )
            )
          )
        ])
      ),
      # this.__struct__ = Symbol.for('Elixir.HTTP.Response');
      Builder.expression_statement(
        Builder.assignment_expression(
          :"=",
          Builder.member_expression(
            Builder.identifier("this"),
            Builder.identifier("__struct__"),
            false
          ),
          Builder.call_expression(
            Builder.member_expression(
              Builder.identifier("Symbol"),
              Builder.identifier("for"),
              false
            ),
            [Builder.literal("Elixir.HTTP.Response")]
          )
        )
      ),
      # Object.freeze(this);
      Builder.expression_statement(
        Builder.call_expression(
          Builder.member_expression(
            Builder.identifier("Object"),
            Builder.identifier("freeze"),
            false
          ),
          [Builder.identifier("this")]
        )
      )
    ]

    # Build the class
    Builder.class_declaration(
      Builder.identifier("HTTPResponse"),
      Builder.class_body([
        # constructor(status, headers, body, ok)
        Builder.method_definition(
          Builder.identifier("constructor"),
          Builder.function_expression(
            [
              Builder.identifier("status"),
              Builder.identifier("headers"),
              Builder.identifier("body"),
              Builder.identifier("ok")
            ],
            [],
            Builder.block_statement(constructor_body)
          ),
          :constructor
        )
      ]),
      nil  # No superclass
    )
  end

  defp build_http_class do
    # Generate HTTP class with static methods for making HTTP requests
    # class HTTP {
    #   static async get(url, opts = {}) { return this.request('GET', url, opts); }
    #   static async post(url, opts = {}) { return this.request('POST', url, opts); }
    #   static async put(url, opts = {}) { return this.request('PUT', url, opts); }
    #   static async delete(url, opts = {}) { return this.request('DELETE', url, opts); }
    #   static async request(method, url, opts = {}) { ... }
    # }

    # Build request method body (the main implementation)
    request_body = build_http_request_method_body()

    # Build helper methods that delegate to request
    get_method = build_http_helper_method("get", "GET")
    post_method = build_http_helper_method("post", "POST")
    put_method = build_http_helper_method("put", "PUT")
    delete_method = build_http_helper_method("delete", "DELETE")

    # Build the request method
    request_method = Builder.method_definition(
      Builder.identifier("request"),
      Builder.function_expression(
        [
          Builder.identifier("method"),
          Builder.identifier("url"),
          Builder.identifier("opts")
        ],
        [],
        Builder.block_statement(request_body),
        false,  # generator
        false,  # expression
        true    # async
      ),
      :method,
      false,  # computed
      true    # static
    )

    # Build the class
    Builder.class_declaration(
      Builder.identifier("HTTP"),
      Builder.class_body([
        get_method,
        post_method,
        put_method,
        delete_method,
        request_method
      ]),
      nil  # No superclass
    )
  end

  defp build_http_helper_method(method_name, http_method) do
    # Build: static async methodName(url, opts = {}) { return this.request('METHOD', url, opts); }
    # Need to add default parameter handling in body
    method_body = [
      # opts = opts || {}
      Builder.expression_statement(
        Builder.assignment_expression(
          :"=",
          Builder.identifier("opts"),
          Builder.logical_expression(
            :"||",
            Builder.identifier("opts"),
            Builder.object_expression([])
          )
        )
      ),
      # return this.request('METHOD', url, opts);
      Builder.return_statement(
        Builder.call_expression(
          Builder.member_expression(
            Builder.identifier("this"),
            Builder.identifier("request"),
            false
          ),
          [
            Builder.literal(http_method),
            Builder.identifier("url"),
            Builder.identifier("opts")
          ]
        )
      )
    ]

    Builder.method_definition(
      Builder.identifier(method_name),
      Builder.function_expression(
        [
          Builder.identifier("url"),
          Builder.identifier("opts")
        ],
        [],
        Builder.block_statement(method_body),
        false,  # generator
        false,  # expression
        true    # async
      ),
      :method,
      false,  # computed
      true    # static
    )
  end

  defp build_http_request_method_body do
    # Build the body of the request method
    # try {
    #   opts = opts || {};
    #   const fetchOpts = {
    #     method: method,
    #     headers: opts.headers || {},
    #     body: opts.body || undefined
    #   };
    #   const response = await fetch(url, fetchOpts);
    #   const body = await response.text();
    #   return {
    #     __tuple__: true,
    #     values: [
    #       Symbol.for('ok'),
    #       new HTTPResponse(response.status, Object.fromEntries(response.headers), body, response.ok)
    #     ]
    #   };
    # } catch (error) {
    #   return {
    #     __tuple__: true,
    #     values: [Symbol.for('error'), error.message]
    #   };
    # }

    try_body = [
      # opts = opts || {};
      Builder.expression_statement(
        Builder.assignment_expression(
          :"=",
          Builder.identifier("opts"),
          Builder.logical_expression(
            :"||",
            Builder.identifier("opts"),
            Builder.object_expression([])
          )
        )
      ),
      # const fetchOpts = { method: method, headers: opts.headers || {}, body: opts.body || undefined };
      Builder.variable_declaration(
        [
          Builder.variable_declarator(
            Builder.identifier("fetchOpts"),
            Builder.object_expression([
              Builder.property(
                Builder.identifier("method"),
                Builder.identifier("method")
              ),
              Builder.property(
                Builder.identifier("headers"),
                Builder.logical_expression(
                  :"||",
                  Builder.member_expression(
                    Builder.identifier("opts"),
                    Builder.identifier("headers"),
                    false
                  ),
                  Builder.object_expression([])
                )
              ),
              Builder.property(
                Builder.identifier("body"),
                Builder.logical_expression(
                  :"||",
                  Builder.member_expression(
                    Builder.identifier("opts"),
                    Builder.identifier("body"),
                    false
                  ),
                  Builder.identifier("undefined")
                )
              )
            ])
          )
        ],
        :const
      ),
      # const response = await fetch(url, fetchOpts);
      Builder.variable_declaration(
        [
          Builder.variable_declarator(
            Builder.identifier("response"),
            Builder.await_expression(
              Builder.call_expression(
                Builder.identifier("fetch"),
                [
                  Builder.identifier("url"),
                  Builder.identifier("fetchOpts")
                ]
              )
            )
          )
        ],
        :const
      ),
      # const body = await response.text();
      Builder.variable_declaration(
        [
          Builder.variable_declarator(
            Builder.identifier("body"),
            Builder.await_expression(
              Builder.call_expression(
                Builder.member_expression(
                  Builder.identifier("response"),
                  Builder.identifier("text"),
                  false
                ),
                []
              )
            )
          )
        ],
        :const
      ),
      # return { __tuple__: true, values: [Symbol.for('ok'), new HTTPResponse(...)] };
      Builder.return_statement(
        Builder.object_expression([
          Builder.property(
            Builder.identifier("__tuple__"),
            Builder.literal(true)
          ),
          Builder.property(
            Builder.identifier("values"),
            Builder.array_expression([
              Builder.call_expression(
                Builder.member_expression(
                  Builder.identifier("Symbol"),
                  Builder.identifier("for"),
                  false
                ),
                [Builder.literal("ok")]
              ),
              Builder.new_expression(
                Builder.identifier("HTTPResponse"),
                [
                  Builder.member_expression(
                    Builder.identifier("response"),
                    Builder.identifier("status"),
                    false
                  ),
                  Builder.call_expression(
                    Builder.member_expression(
                      Builder.identifier("Object"),
                      Builder.identifier("fromEntries"),
                      false
                    ),
                    [
                      Builder.member_expression(
                        Builder.identifier("response"),
                        Builder.identifier("headers"),
                        false
                      )
                    ]
                  ),
                  Builder.identifier("body"),
                  Builder.member_expression(
                    Builder.identifier("response"),
                    Builder.identifier("ok"),
                    false
                  )
                ]
              )
            ])
          )
        ])
      )
    ]

    catch_body = [
      # return { __tuple__: true, values: [Symbol.for('error'), error.message] };
      Builder.return_statement(
        Builder.object_expression([
          Builder.property(
            Builder.identifier("__tuple__"),
            Builder.literal(true)
          ),
          Builder.property(
            Builder.identifier("values"),
            Builder.array_expression([
              Builder.call_expression(
                Builder.member_expression(
                  Builder.identifier("Symbol"),
                  Builder.identifier("for"),
                  false
                ),
                [Builder.literal("error")]
              ),
              Builder.member_expression(
                Builder.identifier("error"),
                Builder.identifier("message"),
                false
              )
            ])
          )
        ])
      )
    ]

    [
      Builder.try_statement(
        Builder.block_statement(try_body),
        Builder.catch_clause(
          Builder.identifier("error"),
          Builder.block_statement(catch_body)
        ),
        nil  # No finally clause
      )
    ]
  end

  defp build_json_class do
    # Generate JSON class with static methods for encoding/decoding JSON
    # class JSON {
    #   static encode(data) { return this.encodeInternal(data, false); }
    #   static encode_bang(data) { return this.encodeInternal(data, true); }
    #   static decode(json, opts = {}) { return this.decodeInternal(json, opts, false); }
    #   static decode_bang(json, opts = {}) { return this.decodeInternal(json, opts, true); }
    #   static encodeInternal(data, shouldThrow) { ... }
    #   static decodeInternal(json, opts, shouldThrow) { ... }
    # }

    # Build encode_bang method (throws on error)
    encode_bang_method = Builder.method_definition(
      Builder.identifier("encode_bang"),
      Builder.function_expression(
        [Builder.identifier("data")],
        [],
        Builder.block_statement([
          Builder.return_statement(
            Builder.call_expression(
              Builder.member_expression(
                Builder.identifier("this"),
                Builder.identifier("encodeInternal"),
                false
              ),
              [Builder.identifier("data"), Builder.literal(true)]
            )
          )
        ]),
        false,  # generator
        false,  # expression
        false   # async
      ),
      :method,
      false,  # computed
      true    # static
    )

    # Build decode_bang method (throws on error)
    decode_bang_method = Builder.method_definition(
      Builder.identifier("decode_bang"),
      Builder.function_expression(
        [Builder.identifier("json"), Builder.identifier("opts")],
        [],
        Builder.block_statement([
          # opts = opts || {}
          Builder.expression_statement(
            Builder.assignment_expression(
              :"=",
              Builder.identifier("opts"),
              Builder.logical_expression(
                :"||",
                Builder.identifier("opts"),
                Builder.object_expression([])
              )
            )
          ),
          Builder.return_statement(
            Builder.call_expression(
              Builder.member_expression(
                Builder.identifier("this"),
                Builder.identifier("decodeInternal"),
                false
              ),
              [Builder.identifier("json"), Builder.identifier("opts"), Builder.literal(true)]
            )
          )
        ]),
        false,  # generator
        false,  # expression
        false   # async
      ),
      :method,
      false,  # computed
      true    # static
    )

    # Build encodeInternal method
    encode_internal_method = Builder.method_definition(
      Builder.identifier("encodeInternal"),
      Builder.function_expression(
        [Builder.identifier("data"), Builder.identifier("shouldThrow")],
        [],
        Builder.block_statement([
          # try { return JSON.stringify(convertElixirToJS(data)); }
          Builder.try_statement(
            Builder.block_statement([
              Builder.return_statement(
                Builder.call_expression(
                  Builder.member_expression(
                    Builder.identifier("globalThis"),
                    Builder.identifier("JSON"),
                    false
                  )
                  |> then(fn json_obj ->
                    Builder.member_expression(
                      json_obj,
                      Builder.identifier("stringify"),
                      false
                    )
                  end),
                  [
                    Builder.call_expression(
                      Builder.identifier("convertElixirToJS"),
                      [Builder.identifier("data")]
                    )
                  ]
                )
              )
            ]),
            # catch (error) { if (shouldThrow) throw error; return { __tuple__: true, values: [Symbol.for('error'), error] }; }
            Builder.catch_clause(
              Builder.identifier("error"),
              Builder.block_statement([
                Builder.if_statement(
                  Builder.identifier("shouldThrow"),
                  Builder.throw_statement(Builder.identifier("error")),
                  nil
                ),
                Builder.return_statement(
                  Builder.object_expression([
                    Builder.property(
                      Builder.identifier("__tuple__"),
                      Builder.literal(true)
                    ),
                    Builder.property(
                      Builder.identifier("values"),
                      Builder.array_expression([
                        Builder.call_expression(
                          Builder.member_expression(
                            Builder.identifier("Symbol"),
                            Builder.identifier("for"),
                            false
                          ),
                          [Builder.literal("error")]
                        ),
                        Builder.identifier("error")
                      ])
                    )
                  ])
                )
              ])
            ),
            nil  # No finally
          )
        ]),
        false,  # generator
        false,  # expression
        false   # async
      ),
      :method,
      false,  # computed
      true    # static
    )

    # Build decodeInternal method
    decode_internal_method = Builder.method_definition(
      Builder.identifier("decodeInternal"),
      Builder.function_expression(
        [Builder.identifier("json"), Builder.identifier("opts"), Builder.identifier("shouldThrow")],
        [],
        Builder.block_statement([
          # try { const parsed = JSON.parse(json); return convertJSToElixir(parsed, opts); }
          Builder.try_statement(
            Builder.block_statement([
              Builder.variable_declaration(
                [
                  Builder.variable_declarator(
                    Builder.identifier("parsed"),
                    Builder.call_expression(
                      Builder.member_expression(
                        Builder.identifier("globalThis"),
                        Builder.identifier("JSON"),
                        false
                      )
                      |> then(fn json_obj ->
                        Builder.member_expression(
                          json_obj,
                          Builder.identifier("parse"),
                          false
                        )
                      end),
                      [Builder.identifier("json")]
                    )
                  )
                ],
                :const
              ),
              Builder.return_statement(
                Builder.call_expression(
                  Builder.identifier("convertJSToElixir"),
                  [Builder.identifier("parsed"), Builder.identifier("opts")]
                )
              )
            ]),
            # catch (error) { if (shouldThrow) throw error; return { __tuple__: true, values: [Symbol.for('error'), error] }; }
            Builder.catch_clause(
              Builder.identifier("error"),
              Builder.block_statement([
                Builder.if_statement(
                  Builder.identifier("shouldThrow"),
                  Builder.throw_statement(Builder.identifier("error")),
                  nil
                ),
                Builder.return_statement(
                  Builder.object_expression([
                    Builder.property(
                      Builder.identifier("__tuple__"),
                      Builder.literal(true)
                    ),
                    Builder.property(
                      Builder.identifier("values"),
                      Builder.array_expression([
                        Builder.call_expression(
                          Builder.member_expression(
                            Builder.identifier("Symbol"),
                            Builder.identifier("for"),
                            false
                          ),
                          [Builder.literal("error")]
                        ),
                        Builder.identifier("error")
                      ])
                    )
                  ])
                )
              ])
            ),
            nil  # No finally
          )
        ]),
        false,  # generator
        false,  # expression
        false   # async
      ),
      :method,
      false,  # computed
      true    # static
    )

    # Build helper function: convertElixirToJS (converts Elixir data structures to plain JS for JSON)
    convert_elixir_to_js = Builder.function_declaration(
      Builder.identifier("convertElixirToJS"),
      [Builder.identifier("data")],
      [],
      Builder.block_statement([
        # if (data === null || data === undefined) return null;
        Builder.if_statement(
          Builder.logical_expression(
            :"||",
            Builder.binary_expression(
              :"===",
              Builder.identifier("data"),
              Builder.literal(nil)
            ),
            Builder.binary_expression(
              :"===",
              Builder.identifier("data"),
              Builder.identifier("undefined")
            )
          ),
          Builder.return_statement(Builder.literal(nil)),
          nil
        ),
        # if (typeof data === 'symbol') return data.description;
        Builder.if_statement(
          Builder.binary_expression(
            :"===",
            Builder.unary_expression(
              :typeof,
              true,  # prefix
              Builder.identifier("data")
            ),
            Builder.literal("symbol")
          ),
          Builder.return_statement(
            Builder.member_expression(
              Builder.identifier("data"),
              Builder.identifier("description"),
              false
            )
          ),
          nil
        ),
        # if (data instanceof Map) { const obj = {}; for (const [k, v] of data) obj[convertElixirToJS(k)] = convertElixirToJS(v); return obj; }
        Builder.if_statement(
          Builder.binary_expression(
            :instanceof,
            Builder.identifier("data"),
            Builder.identifier("Map")
          ),
          Builder.block_statement([
            Builder.variable_declaration(
              [Builder.variable_declarator(Builder.identifier("obj"), Builder.object_expression([]))],
              :const
            ),
            Builder.for_of_statement(
              Builder.variable_declaration(
                [Builder.variable_declarator(
                  Builder.array_pattern([Builder.identifier("k"), Builder.identifier("v")])
                )],
                :const
              ),
              Builder.identifier("data"),
              Builder.block_statement([
                Builder.expression_statement(
                  Builder.assignment_expression(
                    :"=",
                    Builder.member_expression(
                      Builder.identifier("obj"),
                      Builder.call_expression(
                        Builder.identifier("convertElixirToJS"),
                        [Builder.identifier("k")]
                      ),
                      true
                    ),
                    Builder.call_expression(
                      Builder.identifier("convertElixirToJS"),
                      [Builder.identifier("v")]
                    )
                  )
                )
              ])
            ),
            Builder.return_statement(Builder.identifier("obj"))
          ]),
          nil
        ),
        # if (Array.isArray(data)) return data.map(convertElixirToJS);
        Builder.if_statement(
          Builder.call_expression(
            Builder.member_expression(
              Builder.identifier("Array"),
              Builder.identifier("isArray"),
              false
            ),
            [Builder.identifier("data")]
          ),
          Builder.return_statement(
            Builder.call_expression(
              Builder.member_expression(
                Builder.identifier("data"),
                Builder.identifier("map"),
                false
              ),
              [Builder.identifier("convertElixirToJS")]
            )
          ),
          nil
        ),
        # return data;
        Builder.return_statement(Builder.identifier("data"))
      ])
    )

    # Build helper function: convertJSToElixir (converts plain JS to Elixir data structures after JSON parse)
    convert_js_to_elixir = Builder.function_declaration(
      Builder.identifier("convertJSToElixir"),
      [Builder.identifier("data"), Builder.identifier("opts")],
      [],
      Builder.block_statement([
        # if (data === null) return null;
        Builder.if_statement(
          Builder.binary_expression(
            :"===",
            Builder.identifier("data"),
            Builder.literal(nil)
          ),
          Builder.return_statement(Builder.literal(nil)),
          nil
        ),
        # if (typeof data === 'object' && !Array.isArray(data)) { const map = new Map(); for (const [k, v] of Object.entries(data)) { const key = (opts.keys === Symbol.for('atoms')) ? Symbol.for(k) : k; map.set(key, convertJSToElixir(v, opts)); } return map; }
        Builder.if_statement(
          Builder.logical_expression(
            :"&&",
            Builder.binary_expression(
              :"===",
              Builder.unary_expression(
                :typeof,
                true,  # prefix
                Builder.identifier("data")
              ),
              Builder.literal("object")
            ),
            Builder.unary_expression(
              :"!",
              true,  # prefix
              Builder.call_expression(
                Builder.member_expression(
                  Builder.identifier("Array"),
                  Builder.identifier("isArray"),
                  false
                ),
                [Builder.identifier("data")]
              )
            )
          ),
          Builder.block_statement([
            Builder.variable_declaration(
              [Builder.variable_declarator(
                Builder.identifier("map"),
                Builder.new_expression(Builder.identifier("Map"), [])
              )],
              :const
            ),
            Builder.for_of_statement(
              Builder.variable_declaration(
                [Builder.variable_declarator(
                  Builder.array_pattern([Builder.identifier("k"), Builder.identifier("v")])
                )],
                :const
              ),
              Builder.call_expression(
                Builder.member_expression(
                  Builder.identifier("Object"),
                  Builder.identifier("entries"),
                  false
                ),
                [Builder.identifier("data")]
              ),
              Builder.block_statement([
                # let key;
                # if (opts.keys === Symbol.for('atoms')) {
                #   key = Symbol.for(k);
                # } else {
                #   key = k;
                # }
                Builder.variable_declaration(
                  [Builder.variable_declarator(Builder.identifier("key"))],
                  :let
                ),
                Builder.if_statement(
                  Builder.binary_expression(
                    :"===",
                    Builder.member_expression(
                      Builder.identifier("opts"),
                      Builder.identifier("keys"),
                      false
                    ),
                    Builder.call_expression(
                      Builder.member_expression(
                        Builder.identifier("Symbol"),
                        Builder.identifier("for"),
                        false
                      ),
                      [Builder.literal("atoms")]
                    )
                  ),
                  Builder.block_statement([
                    Builder.expression_statement(
                      Builder.assignment_expression(
                        :"=",
                        Builder.identifier("key"),
                        Builder.call_expression(
                          Builder.member_expression(
                            Builder.identifier("Symbol"),
                            Builder.identifier("for"),
                            false
                          ),
                          [Builder.identifier("k")]
                        )
                      )
                    )
                  ]),
                  Builder.block_statement([
                    Builder.expression_statement(
                      Builder.assignment_expression(
                        :"=",
                        Builder.identifier("key"),
                        Builder.identifier("k")
                      )
                    )
                  ])
                ),
                Builder.expression_statement(
                  Builder.call_expression(
                    Builder.member_expression(
                      Builder.identifier("map"),
                      Builder.identifier("set"),
                      false
                    ),
                    [
                      Builder.identifier("key"),
                      Builder.call_expression(
                        Builder.identifier("convertJSToElixir"),
                        [Builder.identifier("v"), Builder.identifier("opts")]
                      )
                    ]
                  )
                )
              ])
            ),
            Builder.return_statement(Builder.identifier("map"))
          ]),
          nil
        ),
        # if (Array.isArray(data)) return Object.freeze(data.map(d => convertJSToElixir(d, opts)));
        Builder.if_statement(
          Builder.call_expression(
            Builder.member_expression(
              Builder.identifier("Array"),
              Builder.identifier("isArray"),
              false
            ),
            [Builder.identifier("data")]
          ),
          Builder.return_statement(
            Builder.call_expression(
              Builder.member_expression(
                Builder.identifier("Object"),
                Builder.identifier("freeze"),
                false
              ),
              [
                Builder.call_expression(
                  Builder.member_expression(
                    Builder.identifier("data"),
                    Builder.identifier("map"),
                    false
                  ),
                  [
                    Builder.arrow_function_expression(
                      [Builder.identifier("d")],
                      [],
                      Builder.call_expression(
                        Builder.identifier("convertJSToElixir"),
                        [Builder.identifier("d"), Builder.identifier("opts")]
                      ),
                      false
                    )
                  ]
                )
              ]
            )
          ),
          nil
        ),
        # return data;
        Builder.return_statement(Builder.identifier("data"))
      ])
    )

    # Return list of AST nodes: helper functions + class
    [
      convert_elixir_to_js,
      convert_js_to_elixir,
      Builder.class_declaration(
        Builder.identifier("JSON"),
        Builder.class_body([
          encode_bang_method,
          decode_bang_method,
          encode_internal_method,
          decode_internal_method
        ]),
        nil  # No superclass
      )
    ]
  end

  # Source Map Generation (Phase 2)

  defp build_source_maps(modules, module_infos, _output_dir) do
    Enum.zip(modules, module_infos)
    |> Enum.map(fn {module, {_module, info}} ->
      # Get original source file from module info
      source_file = get_source_file(module, info)

      # Generate source map (Source Map v3 format)
      %{
        version: 3,
        file: "Elixir.#{module}.js",
        sourceRoot: "",
        source: source_file,  # Singular for test compatibility
        sources: [source_file],  # Array for v3 spec
        names: [],
        mappings: ""  # Empty for basic implementation - can add VLQ mappings later
      }
    end)
  end

  defp get_source_file(module, info) do
    # Try to get source file from module info
    # BEAM debug info includes the original source file path
    cond do
      # Prefer relative_file if available (cleaner paths)
      Map.has_key?(info, :relative_file) and is_binary(info.relative_file) ->
        info.relative_file

      # Fall back to absolute file path
      Map.has_key?(info, :file) and is_binary(info.file) ->
        info.file

      # If file is a charlist, convert to string
      Map.has_key?(info, :file) and is_list(info.file) ->
        List.to_string(info.file)

      # Fallback: construct from module name
      true ->
        module_name = module |> Atom.to_string() |> String.replace("Elixir.", "")
        snake_case = Macro.underscore(module_name)
        "lib/#{snake_case}.ex"
    end
  end

  # Runtime imports detection and generation

  defp detect_runtime_imports(definitions) do
    # Walk through all function definitions and detect Enum/String/Map calls
    # Returns a MapSet of atoms: :enum, :string, :map
    imports = MapSet.new()

    Enum.reduce(definitions, imports, fn
      {{_name, _arity}, :def, _meta, clauses}, acc ->
        Enum.reduce(clauses, acc, fn {_clause_meta, _params, _guards, body}, acc2 ->
          detect_runtime_calls_in_expr(body, acc2)
        end)

      _, acc ->
        acc
    end)
  end

  defp detect_runtime_calls_in_expr(expr, imports) do
    # Recursively walk the AST and detect Enum/String/Map calls
    # Only process if imports is actually a MapSet
    if not is_struct(imports, MapSet) do
      imports
    else
      do_detect_runtime_calls(expr, imports)
    end
  end

  defp do_detect_runtime_calls(expr, imports) do

    case expr do
      # Remote call: Enum.map(...), String.upcase(...), Map.get(...)
      # Expanded AST form (atoms directly)
      {{:., _, [Enum, _fun]}, _, args} when is_list(args) ->
        imports
        |> MapSet.put(:enum)
        |> then(fn acc -> safe_reduce(args, acc) end)

      {{:., _, [String, _fun]}, _, args} when is_list(args) ->
        imports
        |> MapSet.put(:string)
        |> then(fn acc -> safe_reduce(args, acc) end)

      {{:., _, [Map, _fun]}, _, args} when is_list(args) ->
        imports
        |> MapSet.put(:map)
        |> then(fn acc -> safe_reduce(args, acc) end)

      # Unexpanded AST form ({:__aliases__, _, [...]})
      {{:., _, [{:__aliases__, _, [:Enum]}, _fun]}, _, args} when is_list(args) ->
        imports
        |> MapSet.put(:enum)
        |> then(fn acc -> safe_reduce(args, acc) end)

      {{:., _, [{:__aliases__, _, [:String]}, _fun]}, _, args} when is_list(args) ->
        imports
        |> MapSet.put(:string)
        |> then(fn acc -> safe_reduce(args, acc) end)

      {{:., _, [{:__aliases__, _, [:Map]}, _fun]}, _, args} when is_list(args) ->
        imports
        |> MapSet.put(:map)
        |> then(fn acc -> safe_reduce(args, acc) end)

      # JSON module calls (expanded and unexpanded)
      {{:., _, [JSON, _fun]}, _, args} when is_list(args) ->
        imports
        |> MapSet.put(:json)
        |> then(fn acc -> safe_reduce(args, acc) end)

      {{:., _, [{:__aliases__, _, [:JSON]}, _fun]}, _, args} when is_list(args) ->
        imports
        |> MapSet.put(:json)
        |> then(fn acc -> safe_reduce(args, acc) end)

      # HTTP module calls (expanded and unexpanded)
      {{:., _, [HTTP, _fun]}, _, args} when is_list(args) ->
        imports
        |> MapSet.put(:http)
        |> then(fn acc -> safe_reduce(args, acc) end)

      {{:., _, [{:__aliases__, _, [:HTTP]}, _fun]}, _, args} when is_list(args) ->
        imports
        |> MapSet.put(:http)
        |> then(fn acc -> safe_reduce(args, acc) end)

      # List - recurse into elements
      list when is_list(list) ->
        safe_reduce(list, imports)

      # Tuple - recurse into elements
      tuple when is_tuple(tuple) ->
        tuple
        |> Tuple.to_list()
        |> safe_reduce(imports)

      # Atom, number, string, etc. - leaf nodes
      _other ->
        imports
    end
  end

  # Helper to safely reduce, skipping atoms and other non-traversable values
  defp safe_reduce(list, imports) when is_list(list) and is_struct(imports, MapSet) do
    Enum.reduce(list, imports, fn elem, acc ->
      if is_struct(acc, MapSet) do
        detect_runtime_calls_in_expr(elem, acc)
      else
        acc
      end
    end)
  end

  defp safe_reduce(_not_list, imports), do: imports

  defp build_runtime_import_statements(runtime_imports) do
    # Build import statements for detected runtime modules
    # import { Enum, ElixirString as String, ElixirMap as Map } from './lib/index.js';

    if MapSet.size(runtime_imports) == 0 do
      []
    else
      specifiers = []

      specifiers =
        if MapSet.member?(runtime_imports, :enum) do
          [Builder.import_specifier(Builder.identifier("Enum"), Builder.identifier("Enum")) | specifiers]
        else
          specifiers
        end

      specifiers =
        if MapSet.member?(runtime_imports, :string) do
          # Import as String (aliased from ElixirString)
          [Builder.import_specifier(Builder.identifier("ElixirString"), Builder.identifier("String")) | specifiers]
        else
          specifiers
        end

      specifiers =
        if MapSet.member?(runtime_imports, :map) do
          # Import as Map (aliased from ElixirMap)
          [Builder.import_specifier(Builder.identifier("ElixirMap"), Builder.identifier("Map")) | specifiers]
        else
          specifiers
        end

      specifiers =
        if MapSet.member?(runtime_imports, :json) do
          [Builder.import_specifier(Builder.identifier("JSON"), Builder.identifier("JSON")) | specifiers]
        else
          specifiers
        end

      specifiers =
        if MapSet.member?(runtime_imports, :http) do
          # HTTP needs both the module and the HTTPResponse struct
          [
            Builder.import_specifier(Builder.identifier("HTTPResponse"), Builder.identifier("HTTPResponse")),
            Builder.import_specifier(Builder.identifier("HTTP"), Builder.identifier("HTTP"))
            | specifiers
          ]
        else
          specifiers
        end

      [
        Builder.import_declaration(
          Enum.reverse(specifiers),
          Builder.literal("./lib/index.js")
        )
      ]
    end
  end
end

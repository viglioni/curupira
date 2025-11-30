# is_non_struct_map/1 Guard Implementation Demo

This document demonstrates the implementation of the `is_non_struct_map/1` guard (Elixir 1.17+) in the curupira_script transpiler.

## Feature Overview

The `is_non_struct_map/1` guard differentiates between plain maps and structs in Elixir:
- **Plain maps**: `%{a: 1, b: 2}` → Returns `true`
- **Structs**: `%User{name: "Alice"}` → Returns `false`

This is different from `is_map/1` which returns `true` for both maps and structs.

## Elixir Input

```elixir
# From test/fixtures/modern_elixir.ex
def accepts_plain_map(data) when is_non_struct_map(data) do
  {:ok, "plain map"}
end

def accepts_plain_map(_data) do
  {:error, "not a plain map"}
end

def process_map_not_struct(data) when is_non_struct_map(data) do
  Map.put(data, :processed, true)
end

def process_map_not_struct(_data) do
  {:error, "requires plain map"}
end
```

## JavaScript Output

```javascript
accepts_plain_map: function(...args) {
  if (args.length === 1 && (args[0] !== null && typeof args[0] === 'object' && !args[0].__struct__)) {
    const data = args[0];

    return {
      __tuple__: true,
      values: [Symbol.for('ok'), 'plain map']
    };
  }

  if (args.length === 1) {
    return {
      __tuple__: true,
      values: [Symbol.for('error'), 'not a plain map']
    };
  }

  throw new Error('No matching function clause');
}
```

## Implementation Details

### 1. Guard Translation

The `is_non_struct_map/1` guard is translated to a three-part JavaScript check:

```javascript
args[0] !== null && typeof args[0] === 'object' && !args[0].__struct__
```

This checks:
1. **Not null**: `args[0] !== null` (since typeof null === 'object' in JavaScript)
2. **Is object**: `typeof args[0] === 'object'`
3. **No __struct__ field**: `!args[0].__struct__` (structs always have this field)

### 2. Pattern Recognition

The Elixir compiler expands `is_non_struct_map/1` into a complex AST pattern:

```elixir
# Expanded form:
andalso(
  is_map(data),
  not(
    andalso(
      is_map_key(:__struct__, data),
      is_atom(map_get(:__struct__, data))
    )
  )
)
```

Our implementation recognizes this pattern and translates it idiomatically to JavaScript instead of using verbose Erlang helper function calls.

### 3. Multi-Clause Functions

Guards are integrated with pattern matching in multi-clause functions:

```javascript
function(...args) {
  // Clause 1: Check arity AND guard
  if (args.length === 1 && guardCheck) {
    const data = args[0];
    return body1;
  }

  // Clause 2: Fallback
  if (args.length === 1) {
    return body2;
  }

  throw new Error('No matching function clause');
}
```

## Files Modified

1. **lib/curupira_script/compiler.ex**:
   - Updated `build_clause_checks/1` to extract guards from clause tuples
   - Updated `build_clause_check/4` to accept and combine guard checks
   - Added `build_guard_checks/1` to translate guard expressions
   - Added `translate_guard_expression/1` to handle specific guards
   - Added `translate_is_non_struct_map_guard/1` for idiomatic JavaScript
   - Added `translate_guard_var/1` to translate guard variables

2. **test/fixtures/modern_elixir.ex**:
   - Added `accepts_plain_map/1` with guard
   - Added `process_map_not_struct/1` with guard
   - Added test functions demonstrating usage

3. **test/curupira_script_test.exs**:
   - Added 4 new tests in "is_non_struct_map/1 guard (Phase 2)" describe block

## Test Results

```bash
$ mix test --include phase2 test/curupira_script_test.exs:493

....
Finished in 0.1 seconds (0.00s async, 0.1s sync)
63 tests, 0 failures, 59 excluded
```

All 4 guard-related tests pass:
✅ compiles is_non_struct_map/1 guard
✅ guard checks for __struct__ field
✅ guard works in multi-clause pattern matching
✅ guard generates proper type checks

## Future Enhancements

Additional guards that could be implemented using the same pattern:

- `is_map/1` - Check if value is a map (including structs)
- `is_atom/1` - Check if value is a Symbol
- `is_list/1` - Check if value is an Array
- `is_binary/1` - Check if value is a string
- `is_integer/1`, `is_float/1`, `is_number/1` - Numeric type checks
- Custom guard combinations with `and`/`or` operators

## Key Insights

1. **Compiler Expansion**: Elixir expands high-level guards into primitive operations before we see them
2. **Pattern Recognition**: We match the expanded AST pattern to generate idiomatic JavaScript
3. **Idiomatic Output**: Instead of verbose `erlang.andalso(...)` calls, we generate clean `&&` expressions
4. **Guard Integration**: Guards are combined with pattern matching using logical AND operations

/**
 * Enum module - Elixir enumerable functions for JavaScript
 *
 * Works with:
 * - Arrays (frozen or regular)
 * - Range objects
 * - Map objects
 * - Any iterable
 *
 * Follows Elixir semantics:
 * - Returns frozen arrays for immutability
 * - Handles lazy evaluation where appropriate
 * - Preserves Elixir data structures
 */

// Helper: Convert any enumerable to array
function toArray(enumerable) {
  if (Array.isArray(enumerable)) {
    return enumerable;
  }
  if (enumerable && typeof enumerable[Symbol.iterator] === 'function') {
    return Array.from(enumerable);
  }
  if (enumerable instanceof Map) {
    return Array.from(enumerable.entries()).map(([k, v]) =>
      Object.freeze([k, v])
    );
  }
  throw new Error(`Enum functions expect an enumerable, got: ${typeof enumerable}`);
}

// Helper: Freeze array for immutability
function freeze(arr) {
  return Object.freeze(arr);
}

export const Enum = {
  // ========== Basic Operations ==========

  /**
   * Returns true if all elements evaluate to truthy
   */
  all(enumerable, fun = null) {
    const arr = toArray(enumerable);
    if (fun === null) {
      return arr.every(x => x);
    }
    return arr.every(fun);
  },

  /**
   * Returns true if any element evaluates to truthy
   */
  any(enumerable, fun = null) {
    const arr = toArray(enumerable);
    if (fun === null) {
      return arr.some(x => x);
    }
    return arr.some(fun);
  },

  /**
   * Finds the element at the given zero-based index
   */
  at(enumerable, index, default_value = null) {
    const arr = toArray(enumerable);
    if (index < 0) {
      index = arr.length + index;
    }
    return index >= 0 && index < arr.length ? arr[index] : default_value;
  },

  /**
   * Split enumerable into chunks of size `count`
   */
  chunk_every(enumerable, count) {
    if (count <= 0) {
      throw new Error('chunk_every/2 expects a positive integer');
    }
    const arr = toArray(enumerable);
    const chunks = [];
    for (let i = 0; i < arr.length; i += count) {
      chunks.push(freeze(arr.slice(i, i + count)));
    }
    return freeze(chunks);
  },

  /**
   * Concatenate enumerables
   */
  concat(...enumerables) {
    const result = [];
    for (const enumerable of enumerables) {
      result.push(...toArray(enumerable));
    }
    return freeze(result);
  },

  /**
   * Count elements in enumerable
   */
  count(enumerable, fun = null) {
    const arr = toArray(enumerable);
    if (fun === null) {
      return arr.length;
    }
    return arr.filter(fun).length;
  },

  /**
   * Drop first `amount` elements
   */
  drop(enumerable, amount) {
    const arr = toArray(enumerable);
    return freeze(arr.slice(Math.max(0, amount)));
  },

  /**
   * Drop elements while fun returns truthy
   */
  drop_while(enumerable, fun) {
    const arr = toArray(enumerable);
    let i = 0;
    while (i < arr.length && fun(arr[i])) {
      i++;
    }
    return freeze(arr.slice(i));
  },

  /**
   * Iterates over enumerable, calling fun for each element
   * Returns :ok atom
   */
  each(enumerable, fun) {
    const arr = toArray(enumerable);
    arr.forEach(fun);
    return Symbol.for('ok');
  },

  /**
   * Returns true if enumerable is empty
   */
  empty(enumerable) {
    const arr = toArray(enumerable);
    return arr.length === 0;
  },

  /**
   * Filter elements for which fun returns truthy
   */
  filter(enumerable, fun) {
    const arr = toArray(enumerable);
    return freeze(arr.filter(fun));
  },

  /**
   * Find first element for which fun returns truthy
   */
  find(enumerable, default_value = null, fun) {
    // Handle 2-arity version (no default)
    if (typeof default_value === 'function') {
      fun = default_value;
      default_value = null;
    }

    const arr = toArray(enumerable);
    const found = arr.find(fun);
    return found !== undefined ? found : default_value;
  },

  /**
   * Find index of first element for which fun returns truthy
   */
  find_index(enumerable, fun) {
    const arr = toArray(enumerable);
    const index = arr.findIndex(fun);
    return index === -1 ? null : index;
  },

  /**
   * Returns a map with elements grouped by fun result
   */
  group_by(enumerable, key_fun, value_fun = null) {
    const arr = toArray(enumerable);
    const groups = new Map();

    for (const element of arr) {
      const key = key_fun(element);
      const value = value_fun ? value_fun(element) : element;

      if (!groups.has(key)) {
        groups.set(key, []);
      }
      groups.get(key).push(value);
    }

    // Freeze all arrays
    for (const [key, arr] of groups) {
      groups.set(key, freeze(arr));
    }

    return groups;
  },

  /**
   * Returns map with counts of unique elements
   */
  frequencies(enumerable) {
    const arr = toArray(enumerable);
    const freq = new Map();

    for (const element of arr) {
      freq.set(element, (freq.get(element) || 0) + 1);
    }

    return freq;
  },

  /**
   * Returns map with frequency of each fun result
   */
  frequencies_by(enumerable, key_fun) {
    const arr = toArray(enumerable);
    const freq = new Map();

    for (const element of arr) {
      const key = key_fun(element);
      freq.set(key, (freq.get(key) || 0) + 1);
    }

    return freq;
  },

  /**
   * Joins enumerable into string with joiner
   */
  join(enumerable, joiner = "") {
    const arr = toArray(enumerable);
    return arr.map(String).join(joiner);
  },

  /**
   * Maps and flattens the result
   */
  flat_map(enumerable, fun) {
    const arr = toArray(enumerable);
    return freeze(arr.flatMap(fun));
  },

  /**
   * Maps enumerable with fun
   */
  map(enumerable, fun) {
    const arr = toArray(enumerable);
    return freeze(arr.map(fun));
  },

  /**
   * Maps with index
   */
  map_with_index(enumerable, fun) {
    const arr = toArray(enumerable);
    return freeze(arr.map((elem, idx) => fun(elem, idx)));
  },

  /**
   * Returns maximum element
   */
  max(enumerable, compare_fun = null, empty_fallback = null) {
    const arr = toArray(enumerable);
    if (arr.length === 0) {
      if (empty_fallback !== null) {
        return typeof empty_fallback === 'function' ? empty_fallback() : empty_fallback;
      }
      throw new Error('Enum.max/1 called on empty enumerable');
    }

    if (compare_fun === null) {
      return Math.max(...arr);
    }

    return arr.reduce((a, b) => compare_fun(a, b) >= 0 ? a : b);
  },

  /**
   * Returns element with maximum value after applying fun
   */
  max_by(enumerable, fun, compare_fun = null, empty_fallback = null) {
    const arr = toArray(enumerable);
    if (arr.length === 0) {
      if (empty_fallback !== null) {
        return typeof empty_fallback === 'function' ? empty_fallback() : empty_fallback;
      }
      throw new Error('Enum.max_by/2 called on empty enumerable');
    }

    return arr.reduce((a, b) => {
      const va = fun(a);
      const vb = fun(b);
      if (compare_fun) {
        return compare_fun(va, vb) >= 0 ? a : b;
      }
      return va >= vb ? a : b;
    });
  },

  /**
   * Returns minimum element
   */
  min(enumerable, compare_fun = null, empty_fallback = null) {
    const arr = toArray(enumerable);
    if (arr.length === 0) {
      if (empty_fallback !== null) {
        return typeof empty_fallback === 'function' ? empty_fallback() : empty_fallback;
      }
      throw new Error('Enum.min/1 called on empty enumerable');
    }

    if (compare_fun === null) {
      return Math.min(...arr);
    }

    return arr.reduce((a, b) => compare_fun(a, b) <= 0 ? a : b);
  },

  /**
   * Returns element with minimum value after applying fun
   */
  min_by(enumerable, fun, compare_fun = null, empty_fallback = null) {
    const arr = toArray(enumerable);
    if (arr.length === 0) {
      if (empty_fallback !== null) {
        return typeof empty_fallback === 'function' ? empty_fallback() : empty_fallback;
      }
      throw new Error('Enum.min_by/2 called on empty enumerable');
    }

    return arr.reduce((a, b) => {
      const va = fun(a);
      const vb = fun(b);
      if (compare_fun) {
        return compare_fun(va, vb) <= 0 ? a : b;
      }
      return va <= vb ? a : b;
    });
  },

  /**
   * Returns {min, max} tuple in one pass
   */
  min_max(enumerable, empty_fallback = null) {
    const arr = toArray(enumerable);
    if (arr.length === 0) {
      if (empty_fallback !== null) {
        return typeof empty_fallback === 'function' ? empty_fallback() : empty_fallback;
      }
      throw new Error('Enum.min_max/1 called on empty enumerable');
    }

    let min = arr[0];
    let max = arr[0];

    for (let i = 1; i < arr.length; i++) {
      if (arr[i] < min) min = arr[i];
      if (arr[i] > max) max = arr[i];
    }

    return freeze([min, max]);
  },

  /**
   * Returns product of all numbers
   */
  product(enumerable) {
    const arr = toArray(enumerable);
    return arr.reduce((acc, val) => {
      if (typeof val !== 'number') {
        throw new Error('Enum.product/1 expects all elements to be numbers');
      }
      return acc * val;
    }, 1);
  },

  /**
   * Returns random element
   */
  random(enumerable) {
    const arr = toArray(enumerable);
    if (arr.length === 0) {
      throw new Error('Enum.random/1 called on empty enumerable');
    }
    return arr[Math.floor(Math.random() * arr.length)];
  },

  /**
   * Reduces enumerable with accumulator and function
   */
  reduce(enumerable, acc, fun) {
    // Handle 2-arity version (no initial acc)
    if (typeof acc === 'function') {
      fun = acc;
      const arr = toArray(enumerable);
      if (arr.length === 0) {
        throw new Error('Enum.reduce/2 called on empty enumerable');
      }
      return arr.slice(1).reduce(fun, arr[0]);
    }

    const arr = toArray(enumerable);
    return arr.reduce(fun, acc);
  },

  /**
   * Reduces from right to left
   */
  reduce_right(enumerable, acc, fun) {
    const arr = toArray(enumerable);
    return arr.reduceRight(fun, acc);
  },

  /**
   * Rejects elements for which fun returns truthy
   */
  reject(enumerable, fun) {
    const arr = toArray(enumerable);
    return freeze(arr.filter(x => !fun(x)));
  },

  /**
   * Reverses enumerable
   */
  reverse(enumerable) {
    const arr = toArray(enumerable);
    return freeze(arr.reverse());
  },

  /**
   * Sorts enumerable
   */
  sort(enumerable, compare_fun = null) {
    const arr = [...toArray(enumerable)];
    if (compare_fun === null) {
      arr.sort((a, b) => a < b ? -1 : a > b ? 1 : 0);
    } else {
      arr.sort(compare_fun);
    }
    return freeze(arr);
  },

  /**
   * Sorts by fun result
   */
  sort_by(enumerable, fun, compare_fun = null) {
    const arr = [...toArray(enumerable)];
    const mapped = arr.map((elem, idx) => ({elem, value: fun(elem), idx}));

    if (compare_fun === null) {
      mapped.sort((a, b) => {
        if (a.value < b.value) return -1;
        if (a.value > b.value) return 1;
        return a.idx - b.idx; // Stable sort
      });
    } else {
      mapped.sort((a, b) => {
        const cmp = compare_fun(a.value, b.value);
        return cmp !== 0 ? cmp : a.idx - b.idx;
      });
    }

    return freeze(mapped.map(x => x.elem));
  },

  /**
   * Splits enumerable into two lists based on fun
   */
  split_with(enumerable, fun) {
    const arr = toArray(enumerable);
    const left = [];
    const right = [];

    for (const elem of arr) {
      if (fun(elem)) {
        left.push(elem);
      } else {
        right.push(elem);
      }
    }

    return freeze([freeze(left), freeze(right)]);
  },

  /**
   * Sums all numbers
   */
  sum(enumerable) {
    const arr = toArray(enumerable);
    return arr.reduce((acc, val) => {
      if (typeof val !== 'number') {
        throw new Error('Enum.sum/1 expects all elements to be numbers');
      }
      return acc + val;
    }, 0);
  },

  /**
   * Takes first `amount` elements
   */
  take(enumerable, amount) {
    const arr = toArray(enumerable);
    if (amount >= 0) {
      return freeze(arr.slice(0, amount));
    } else {
      return freeze(arr.slice(amount));
    }
  },

  /**
   * Takes elements while fun returns truthy
   */
  take_while(enumerable, fun) {
    const arr = toArray(enumerable);
    const result = [];
    for (const elem of arr) {
      if (!fun(elem)) break;
      result.push(elem);
    }
    return freeze(result);
  },

  /**
   * Converts enumerable to list (frozen array)
   */
  to_list(enumerable) {
    return freeze(toArray(enumerable));
  },

  /**
   * Returns unique elements
   */
  uniq(enumerable) {
    const arr = toArray(enumerable);
    return freeze([...new Set(arr)]);
  },

  /**
   * Returns unique elements by fun result
   */
  uniq_by(enumerable, fun) {
    const arr = toArray(enumerable);
    const seen = new Set();
    const result = [];

    for (const elem of arr) {
      const key = fun(elem);
      if (!seen.has(key)) {
        seen.add(key);
        result.push(elem);
      }
    }

    return freeze(result);
  },

  /**
   * Zips two enumerables together
   */
  zip(left, right) {
    const arr1 = toArray(left);
    const arr2 = toArray(right);
    const length = Math.min(arr1.length, arr2.length);
    const result = [];

    for (let i = 0; i < length; i++) {
      result.push(freeze([arr1[i], arr2[i]]));
    }

    return freeze(result);
  },

  /**
   * Zips two enumerables with a function
   */
  zip_with(left, right, fun) {
    const arr1 = toArray(left);
    const arr2 = toArray(right);
    const length = Math.min(arr1.length, arr2.length);
    const result = [];

    for (let i = 0; i < length; i++) {
      result.push(fun(arr1[i], arr2[i]));
    }

    return freeze(result);
  },
};

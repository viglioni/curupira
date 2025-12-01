/**
 * Map module - Elixir map functions for JavaScript
 *
 * Works with JavaScript Map objects
 * Preserves Elixir semantics:
 * - Maps are mutable in this implementation (JS limitation)
 * - Keys can be any type (including symbols for atoms)
 * - Returns new Maps for transformations
 */

export const ElixirMap = {
  // ========== Creation ==========

  /**
   * Creates a new map from enumerable of {key, value} tuples
   */
  new(enumerable = []) {
    const map = new Map();

    if (Array.isArray(enumerable)) {
      for (const item of enumerable) {
        if (Array.isArray(item) && item.length === 2) {
          map.set(item[0], item[1]);
        } else if (item && item.__tuple__ && item.values && item.values.length === 2) {
          map.set(item.values[0], item.values[1]);
        } else {
          throw new Error('Map.new/1 expects enumerable of {key, value} tuples');
        }
      }
    } else if (enumerable instanceof Map) {
      return new Map(enumerable);
    } else if (typeof enumerable[Symbol.iterator] === 'function') {
      for (const item of enumerable) {
        if (Array.isArray(item) && item.length === 2) {
          map.set(item[0], item[1]);
        }
      }
    }

    return map;
  },

  // ========== Access ==========

  /**
   * Gets value for key, returns default if not found
   */
  get(map, key, default_value = null) {
    if (!(map instanceof Map)) {
      throw new Error('Map.get/2 expects a map');
    }
    return map.has(key) ? map.get(key) : default_value;
  },

  /**
   * Fetches value for key, returns {:ok, value} or :error
   */
  fetch(map, key) {
    if (!(map instanceof Map)) {
      throw new Error('Map.fetch/2 expects a map');
    }

    if (map.has(key)) {
      return Object.freeze({
        __tuple__: true,
        values: [Symbol.for('ok'), map.get(key)]
      });
    }

    return Symbol.for('error');
  },

  /**
   * Gets value for key, throws if not found
   */
  fetch_bang(map, key) {
    if (!(map instanceof Map)) {
      throw new Error('Map.fetch!/2 expects a map');
    }

    if (map.has(key)) {
      return map.get(key);
    }

    throw new Error(`Map.fetch!/2: key ${key} not found in map`);
  },

  /**
   * Checks if map has key
   */
  has_key(map, key) {
    if (!(map instanceof Map)) {
      throw new Error('Map.has_key?/2 expects a map');
    }
    return map.has(key);
  },

  /**
   * Returns list of keys
   */
  keys(map) {
    if (!(map instanceof Map)) {
      throw new Error('Map.keys/1 expects a map');
    }
    return Object.freeze(Array.from(map.keys()));
  },

  /**
   * Returns list of values
   */
  values(map) {
    if (!(map instanceof Map)) {
      throw new Error('Map.values/1 expects a map');
    }
    return Object.freeze(Array.from(map.values()));
  },

  // ========== Modification ==========

  /**
   * Puts key-value pair in map, returns new map
   */
  put(map, key, value) {
    if (!(map instanceof Map)) {
      throw new Error('Map.put/3 expects a map');
    }
    const new_map = new Map(map);
    new_map.set(key, value);
    return new_map;
  },

  /**
   * Puts key-value pair only if key doesn't exist
   */
  put_new(map, key, value) {
    if (!(map instanceof Map)) {
      throw new Error('Map.put_new/3 expects a map');
    }
    if (map.has(key)) {
      return new Map(map);
    }
    const new_map = new Map(map);
    new_map.set(key, value);
    return new_map;
  },

  /**
   * Deletes key from map, returns new map
   */
  delete(map, key) {
    if (!(map instanceof Map)) {
      throw new Error('Map.delete/2 expects a map');
    }
    const new_map = new Map(map);
    new_map.delete(key);
    return new_map;
  },

  /**
   * Drops specified keys from map
   */
  drop(map, keys) {
    if (!(map instanceof Map)) {
      throw new Error('Map.drop/2 expects a map');
    }
    const new_map = new Map(map);
    for (const key of keys) {
      new_map.delete(key);
    }
    return new_map;
  },

  /**
   * Takes only specified keys from map
   */
  take(map, keys) {
    if (!(map instanceof Map)) {
      throw new Error('Map.take/2 expects a map');
    }
    const new_map = new Map();
    for (const key of keys) {
      if (map.has(key)) {
        new_map.set(key, map.get(key));
      }
    }
    return new_map;
  },

  /**
   * Merges two maps, second map wins conflicts
   */
  merge(map1, map2, merge_fun = null) {
    if (!(map1 instanceof Map) || !(map2 instanceof Map)) {
      throw new Error('Map.merge/2 expects two maps');
    }

    const new_map = new Map(map1);

    if (merge_fun === null) {
      for (const [key, value] of map2) {
        new_map.set(key, value);
      }
    } else {
      for (const [key, value] of map2) {
        if (new_map.has(key)) {
          new_map.set(key, merge_fun(key, new_map.get(key), value));
        } else {
          new_map.set(key, value);
        }
      }
    }

    return new_map;
  },

  /**
   * Updates value at key with function
   */
  update(map, key, initial, fun) {
    if (!(map instanceof Map)) {
      throw new Error('Map.update/4 expects a map');
    }

    const new_map = new Map(map);

    if (map.has(key)) {
      new_map.set(key, fun(map.get(key)));
    } else {
      new_map.set(key, initial);
    }

    return new_map;
  },

  /**
   * Updates existing value at key with function, errors if not found
   */
  update_bang(map, key, fun) {
    if (!(map instanceof Map)) {
      throw new Error('Map.update!/3 expects a map');
    }

    if (!map.has(key)) {
      throw new Error(`Map.update!/3: key ${key} not found in map`);
    }

    const new_map = new Map(map);
    new_map.set(key, fun(map.get(key)));
    return new_map;
  },

  // ========== Filtering & Transformation ==========

  /**
   * Filters map by function returning truthy for {key, value} to keep
   */
  filter(map, fun) {
    if (!(map instanceof Map)) {
      throw new Error('Map.filter/2 expects a map');
    }

    const new_map = new Map();

    for (const [key, value] of map) {
      if (fun(key, value)) {
        new_map.set(key, value);
      }
    }

    return new_map;
  },

  /**
   * Rejects map entries where function returns truthy
   */
  reject(map, fun) {
    if (!(map instanceof Map)) {
      throw new Error('Map.reject/2 expects a map');
    }

    const new_map = new Map();

    for (const [key, value] of map) {
      if (!fun(key, value)) {
        new_map.set(key, value);
      }
    }

    return new_map;
  },

  /**
   * Maps over values, keeping keys the same
   */
  map(map, fun) {
    if (!(map instanceof Map)) {
      throw new Error('Map.map/2 expects a map');
    }

    const new_map = new Map();

    for (const [key, value] of map) {
      new_map.set(key, fun(key, value));
    }

    return new_map;
  },

  // ========== Splitting ==========

  /**
   * Splits map into two based on keys list
   */
  split(map, keys) {
    if (!(map instanceof Map)) {
      throw new Error('Map.split/2 expects a map');
    }

    const taken = new Map();
    const rest = new Map();
    const keys_set = new Set(keys);

    for (const [key, value] of map) {
      if (keys_set.has(key)) {
        taken.set(key, value);
      } else {
        rest.set(key, value);
      }
    }

    return Object.freeze([taken, rest]);
  },

  /**
   * Splits map with function, truthy goes to first map
   */
  split_with(map, fun) {
    if (!(map instanceof Map)) {
      throw new Error('Map.split_with/2 expects a map');
    }

    const left = new Map();
    const right = new Map();

    for (const [key, value] of map) {
      if (fun(key, value)) {
        left.set(key, value);
      } else {
        right.set(key, value);
      }
    }

    return Object.freeze([left, right]);
  },

  // ========== Size & Checks ==========

  /**
   * Returns number of entries in map
   */
  size(map) {
    if (!(map instanceof Map)) {
      throw new Error('Map.size/1 expects a map');
    }
    return map.size;
  },

  /**
   * Returns true if map is empty
   */
  empty(map) {
    if (!(map instanceof Map)) {
      throw new Error('Map.empty?/1 expects a map');
    }
    return map.size === 0;
  },

  /**
   * Checks if two maps are equal
   */
  equal(map1, map2) {
    if (!(map1 instanceof Map) || !(map2 instanceof Map)) {
      return false;
    }

    if (map1.size !== map2.size) {
      return false;
    }

    for (const [key, value] of map1) {
      if (!map2.has(key) || map2.get(key) !== value) {
        return false;
      }
    }

    return true;
  },

  // ========== Conversion ==========

  /**
   * Converts map to list of {key, value} tuples
   */
  to_list(map) {
    if (!(map instanceof Map)) {
      throw new Error('Map.to_list/1 expects a map');
    }

    return Object.freeze(
      Array.from(map.entries(), ([k, v]) => Object.freeze([k, v]))
    );
  },

  /**
   * Creates map from struct (removes __struct__ key)
   */
  from_struct(struct) {
    if (!struct || typeof struct !== 'object') {
      throw new Error('Map.from_struct/1 expects a struct');
    }

    const map = new Map();

    for (const [key, value] of Object.entries(struct)) {
      if (key !== '__struct__') {
        map.set(Symbol.for(key), value);
      }
    }

    return map;
  },
};

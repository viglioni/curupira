/**
 * JSON encoding/decoding for Elixir data structures
 *
 * Handles conversion between Elixir types (symbols for atoms, Maps, frozen arrays)
 * and JavaScript JSON-compatible types.
 */

function convertElixirToJS(data) {
  if (data === null || data === undefined) return null;

  // Atoms -> strings
  if (typeof data === 'symbol') return data.description;

  // Elixir Maps -> plain objects
  if (data instanceof Map) {
    const obj = {};
    for (const [k, v] of data) {
      obj[convertElixirToJS(k)] = convertElixirToJS(v);
    }
    return obj;
  }

  // Arrays (recursively convert elements)
  if (Array.isArray(data)) {
    return data.map(convertElixirToJS);
  }

  return data;
}

function convertJSToElixir(data, opts) {
  if (data === null) return null;

  // Plain objects -> Elixir Maps
  if (typeof data === 'object' && !Array.isArray(data)) {
    const map = new Map();
    for (const [k, v] of Object.entries(data)) {
      let key;
      if (opts.keys === Symbol.for('atoms')) {
        key = Symbol.for(k);
      } else {
        key = k;
      }
      map.set(key, convertJSToElixir(v, opts));
    }
    return map;
  }

  // Arrays (recursively convert, freeze for immutability)
  if (Array.isArray(data)) {
    return Object.freeze(data.map(d => convertJSToElixir(d, opts)));
  }

  return data;
}

export const JSON = {
  /**
   * Encode Elixir data to JSON string (safe version)
   * @returns {{__tuple__: true, values: [symbol, string]} | {__tuple__: true, values: [symbol, null, string]}}
   */
  encode(data) {
    try {
      const json = globalThis.JSON.stringify(convertElixirToJS(data));
      return { __tuple__: true, values: [Symbol.for('ok'), json] };
    } catch (error) {
      return { __tuple__: true, values: [Symbol.for('error'), null, error.message] };
    }
  },

  /**
   * Encode Elixir data to JSON string (throws on error)
   * @returns {string}
   */
  encode_bang(data) {
    return globalThis.JSON.stringify(convertElixirToJS(data));
  },

  /**
   * Decode JSON string to Elixir data (safe version)
   * @param {string} json - JSON string to decode
   * @param {{keys?: symbol}} opts - Options (keys: Symbol.for('atoms') for atom keys)
   * @returns {{__tuple__: true, values: [symbol, any]} | {__tuple__: true, values: [symbol, string]}}
   */
  decode(json, opts = {}) {
    try {
      const data = globalThis.JSON.parse(json);
      const result = convertJSToElixir(data, opts);
      return { __tuple__: true, values: [Symbol.for('ok'), result] };
    } catch (error) {
      return { __tuple__: true, values: [Symbol.for('error'), error.message] };
    }
  },

  /**
   * Decode JSON string to Elixir data (throws on error)
   * @param {string} json - JSON string to decode
   * @param {{keys?: symbol}} opts - Options (keys: Symbol.for('atoms') for atom keys)
   * @returns {any}
   */
  decode_bang(json, opts = {}) {
    const data = globalThis.JSON.parse(json);
    return convertJSToElixir(data, opts);
  }
};

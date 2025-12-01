/**
 * String module - Elixir string functions for JavaScript
 *
 * Handles:
 * - UTF-8 strings
 * - Grapheme clusters
 * - Trim/pad operations
 * - Replace operations
 * - Case conversion
 */

export const ElixirString = {
  // ========== Length & Size ==========

  /**
   * Returns the number of Unicode graphemes in string
   */
  length(string) {
    if (typeof string !== 'string') {
      throw new Error('String.length/1 expects a string');
    }
    // Use Intl.Segmenter for proper grapheme counting
    if (typeof Intl !== 'undefined' && Intl.Segmenter) {
      const segmenter = new Intl.Segmenter('en', { granularity: 'grapheme' });
      return Array.from(segmenter.segment(string)).length;
    }
    // Fallback: count code points
    return Array.from(string).length;
  },

  // ========== Case Conversion ==========

  /**
   * Converts string to lowercase
   */
  downcase(string) {
    if (typeof string !== 'string') {
      throw new Error('String.downcase/1 expects a string');
    }
    return string.toLowerCase();
  },

  /**
   * Converts string to uppercase
   */
  upcase(string) {
    if (typeof string !== 'string') {
      throw new Error('String.upcase/1 expects a string');
    }
    return string.toUpperCase();
  },

  /**
   * Capitalizes first character, lowercases rest
   */
  capitalize(string) {
    if (typeof string !== 'string') {
      throw new Error('String.capitalize/1 expects a string');
    }
    if (string.length === 0) return string;
    return string[0].toUpperCase() + string.slice(1).toLowerCase();
  },

  // ========== Trim Operations ==========

  /**
   * Removes leading and trailing whitespace
   */
  trim(string) {
    if (typeof string !== 'string') {
      throw new Error('String.trim/1 expects a string');
    }
    return string.trim();
  },

  /**
   * Removes leading whitespace
   */
  trim_leading(string) {
    if (typeof string !== 'string') {
      throw new Error('String.trim_leading/1 expects a string');
    }
    return string.replace(/^\s+/, '');
  },

  /**
   * Removes trailing whitespace
   */
  trim_trailing(string) {
    if (typeof string !== 'string') {
      throw new Error('String.trim_trailing/1 expects a string');
    }
    return string.replace(/\s+$/, '');
  },

  // ========== Pad Operations ==========

  /**
   * Pads string to length with leading spaces
   */
  pad_leading(string, length, padding = " ") {
    if (typeof string !== 'string') {
      throw new Error('String.pad_leading/2 expects a string');
    }
    if (string.length >= length) return string;
    const pad_length = length - string.length;
    const full_pads = Math.floor(pad_length / padding.length);
    const remaining = pad_length % padding.length;
    return padding.repeat(full_pads) + padding.slice(0, remaining) + string;
  },

  /**
   * Pads string to length with trailing spaces
   */
  pad_trailing(string, length, padding = " ") {
    if (typeof string !== 'string') {
      throw new Error('String.pad_trailing/2 expects a string');
    }
    if (string.length >= length) return string;
    const pad_length = length - string.length;
    const full_pads = Math.floor(pad_length / padding.length);
    const remaining = pad_length % padding.length;
    return string + padding.repeat(full_pads) + padding.slice(0, remaining);
  },

  // ========== Split & Join ==========

  /**
   * Splits string by pattern
   */
  split(string, pattern = "", options = {}) {
    if (typeof string !== 'string') {
      throw new Error('String.split/2 expects a string');
    }

    const parts = options.trim ? string.trim() : string;
    const limit = options.parts || Infinity;

    if (pattern === "") {
      // Split into graphemes
      if (typeof Intl !== 'undefined' && Intl.Segmenter) {
        const segmenter = new Intl.Segmenter('en', { granularity: 'grapheme' });
        return Object.freeze(Array.from(segmenter.segment(parts), s => s.segment).slice(0, limit));
      }
      return Object.freeze(Array.from(parts).slice(0, limit));
    }

    if (typeof pattern === 'string') {
      const result = parts.split(pattern);
      return Object.freeze(limit === Infinity ? result : result.slice(0, limit));
    }

    if (pattern instanceof RegExp) {
      const result = parts.split(pattern);
      return Object.freeze(limit === Infinity ? result : result.slice(0, limit));
    }

    throw new Error('String.split/2 expects pattern to be string or regex');
  },

  // ========== Replace Operations ==========

  /**
   * Replaces all occurrences of pattern with replacement
   */
  replace(string, pattern, replacement) {
    if (typeof string !== 'string') {
      throw new Error('String.replace/3 expects a string');
    }

    if (typeof pattern === 'string') {
      return string.split(pattern).join(replacement);
    }

    if (pattern instanceof RegExp) {
      // Ensure global flag
      const flags = pattern.flags.includes('g') ? pattern.flags : pattern.flags + 'g';
      const global_pattern = new RegExp(pattern.source, flags);
      return string.replace(global_pattern, replacement);
    }

    throw new Error('String.replace/3 expects pattern to be string or regex');
  },

  /**
   * Replaces prefix if present
   */
  replace_prefix(string, match, replacement) {
    if (typeof string !== 'string') {
      throw new Error('String.replace_prefix/3 expects a string');
    }
    if (string.startsWith(match)) {
      return replacement + string.slice(match.length);
    }
    return string;
  },

  /**
   * Replaces suffix if present
   */
  replace_suffix(string, match, replacement) {
    if (typeof string !== 'string') {
      throw new Error('String.replace_suffix/3 expects a string');
    }
    if (string.endsWith(match)) {
      return string.slice(0, -match.length) + replacement;
    }
    return string;
  },

  // ========== Slice & Extract ==========

  /**
   * Returns substring from start to end
   */
  slice(string, start, length = null) {
    if (typeof string !== 'string') {
      throw new Error('String.slice/2 expects a string');
    }

    // Handle negative indices
    if (start < 0) {
      start = string.length + start;
    }

    if (length === null) {
      return string.slice(start);
    }

    if (length < 0) {
      return "";
    }

    return string.slice(start, start + length);
  },

  /**
   * Returns first grapheme or null
   */
  first(string) {
    if (typeof string !== 'string') {
      throw new Error('String.first/1 expects a string');
    }
    if (string.length === 0) return null;

    if (typeof Intl !== 'undefined' && Intl.Segmenter) {
      const segmenter = new Intl.Segmenter('en', { granularity: 'grapheme' });
      const segments = segmenter.segment(string);
      return segments[Symbol.iterator]().next().value?.segment || null;
    }

    return string[0];
  },

  /**
   * Returns last grapheme or null
   */
  last(string) {
    if (typeof string !== 'string') {
      throw new Error('String.last/1 expects a string');
    }
    if (string.length === 0) return null;

    if (typeof Intl !== 'undefined' && Intl.Segmenter) {
      const segmenter = new Intl.Segmenter('en', { granularity: 'grapheme' });
      const segments = Array.from(segmenter.segment(string));
      return segments[segments.length - 1]?.segment || null;
    }

    return string[string.length - 1];
  },

  /**
   * Returns grapheme at position
   */
  at(string, position) {
    if (typeof string !== 'string') {
      throw new Error('String.at/2 expects a string');
    }

    if (typeof Intl !== 'undefined' && Intl.Segmenter) {
      const segmenter = new Intl.Segmenter('en', { granularity: 'grapheme' });
      const segments = Array.from(segmenter.segment(string));

      // Handle negative indices
      if (position < 0) {
        position = segments.length + position;
      }

      if (position >= 0 && position < segments.length) {
        return segments[position].segment;
      }
      return null;
    }

    // Fallback
    if (position < 0) {
      position = string.length + position;
    }
    return position >= 0 && position < string.length ? string[position] : null;
  },

  // ========== Graphemes ==========

  /**
   * Returns list of graphemes
   */
  graphemes(string) {
    if (typeof string !== 'string') {
      throw new Error('String.graphemes/1 expects a string');
    }

    if (typeof Intl !== 'undefined' && Intl.Segmenter) {
      const segmenter = new Intl.Segmenter('en', { granularity: 'grapheme' });
      return Object.freeze(Array.from(segmenter.segment(string), s => s.segment));
    }

    // Fallback: split into code points
    return Object.freeze(Array.from(string));
  },

  // ========== Contains & Checks ==========

  /**
   * Checks if string contains substring
   */
  contains(string, substring) {
    if (typeof string !== 'string') {
      throw new Error('String.contains?/2 expects a string');
    }
    return string.includes(substring);
  },

  /**
   * Checks if string starts with prefix
   */
  starts_with(string, prefix) {
    if (typeof string !== 'string') {
      throw new Error('String.starts_with?/2 expects a string');
    }
    return string.startsWith(prefix);
  },

  /**
   * Checks if string ends with suffix
   */
  ends_with(string, suffix) {
    if (typeof string !== 'string') {
      throw new Error('String.ends_with?/2 expects a string');
    }
    return string.endsWith(suffix);
  },

  // ========== Reverse & Duplicate ==========

  /**
   * Reverses string
   */
  reverse(string) {
    if (typeof string !== 'string') {
      throw new Error('String.reverse/1 expects a string');
    }

    if (typeof Intl !== 'undefined' && Intl.Segmenter) {
      const segmenter = new Intl.Segmenter('en', { granularity: 'grapheme' });
      const segments = Array.from(segmenter.segment(string), s => s.segment);
      return segments.reverse().join('');
    }

    return Array.from(string).reverse().join('');
  },

  /**
   * Duplicates string n times
   */
  duplicate(string, n) {
    if (typeof string !== 'string') {
      throw new Error('String.duplicate/2 expects a string');
    }
    if (n < 0) {
      throw new Error('String.duplicate/2 expects non-negative count');
    }
    return string.repeat(n);
  },
};

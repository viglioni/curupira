/**
 * Range class supporting stepped ranges (Elixir 1.12+)
 * Supports iteration via Symbol.iterator
 *
 * Examples:
 *   new Range(1, 10)       // [1, 2, 3, ..., 10]
 *   new Range(1, 10, 2)    // [1, 3, 5, 7, 9]
 *   new Range(10, 1, -1)   // [10, 9, 8, ..., 1]
 *   new Range(0, 100, 10)  // [0, 10, 20, ..., 100]
 */
export class Range {
  constructor(first, last, step = null) {
    this.first = first;
    this.last = last;
    // Auto-detect step direction if not provided
    this.step = step !== null ? step : (first <= last ? 1 : -1);
    this.__struct__ = Symbol.for('Elixir.Range');
  }

  // Make Range iterable
  *[Symbol.iterator]() {
    const { first, last, step } = this;

    if (step === 0) {
      throw new Error('Range step cannot be 0');
    }

    if (step > 0) {
      for (let i = first; i <= last; i += step) {
        yield i;
      }
    } else if (step < 0) {
      for (let i = first; i >= last; i += step) {
        yield i;
      }
    }
  }

  // Convert to array (for Enum operations)
  toArray() {
    return Array.from(this);
  }

  // Length/size
  size() {
    const { first, last, step } = this;
    if (step > 0) {
      return Math.max(0, Math.floor((last - first) / step) + 1);
    } else {
      return Math.max(0, Math.floor((first - last) / Math.abs(step)) + 1);
    }
  }

  // Check if value is in range
  member(value) {
    const { first, last, step } = this;

    if (step > 0) {
      return value >= first && value <= last && (value - first) % step === 0;
    } else {
      return value <= first && value >= last && (first - value) % Math.abs(step) === 0;
    }
  }
}

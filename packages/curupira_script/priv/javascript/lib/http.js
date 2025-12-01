/**
 * HTTP client for making web requests
 *
 * Provides HTTPoison/Req-style API using native fetch().
 * Works in Node.js 18+ and all modern browsers.
 */

/**
 * HTTP Response struct
 */
export class HTTPResponse {
  constructor(status, headers, body, ok) {
    this.status = status;
    this.headers = headers;
    this.body = body;
    this.ok = ok;
  }
}

/**
 * HTTP client module
 */
export const HTTP = {
  /**
   * Make a GET request
   * @param {string} url - URL to request
   * @param {{headers?: object}} opts - Request options
   * @returns {Promise<{__tuple__: true, values: [symbol, HTTPResponse]}>}
   */
  async get(url, opts = {}) {
    return this.request('GET', url, opts);
  },

  /**
   * Make a POST request
   * @param {string} url - URL to request
   * @param {{body?: any, headers?: object}} opts - Request options
   * @returns {Promise<{__tuple__: true, values: [symbol, HTTPResponse]}>}
   */
  async post(url, opts = {}) {
    return this.request('POST', url, opts);
  },

  /**
   * Make a PUT request
   * @param {string} url - URL to request
   * @param {{body?: any, headers?: object}} opts - Request options
   * @returns {Promise<{__tuple__: true, values: [symbol, HTTPResponse]}>}
   */
  async put(url, opts = {}) {
    return this.request('PUT', url, opts);
  },

  /**
   * Make a DELETE request
   * @param {string} url - URL to request
   * @param {{headers?: object}} opts - Request options
   * @returns {Promise<{__tuple__: true, values: [symbol, HTTPResponse]}>}
   */
  async delete(url, opts = {}) {
    return this.request('DELETE', url, opts);
  },

  /**
   * Make an HTTP request
   * @param {string} method - HTTP method (GET, POST, PUT, DELETE, etc.)
   * @param {string} url - URL to request
   * @param {{body?: any, headers?: object}} opts - Request options
   * @returns {Promise<{__tuple__: true, values: [symbol, HTTPResponse]}>}
   */
  async request(method, url, opts = {}) {
    try {
      const fetchOpts = {
        method: method,
        headers: opts.headers || {}
      };

      if (opts.body !== undefined) {
        fetchOpts.body = opts.body;
      }

      const response = await fetch(url, fetchOpts);
      const body = await response.text();

      const httpResponse = new HTTPResponse(
        response.status,
        Object.fromEntries(response.headers.entries()),
        body,
        response.ok
      );

      return {
        __tuple__: true,
        values: [Symbol.for('ok'), httpResponse]
      };
    } catch (error) {
      return {
        __tuple__: true,
        values: [Symbol.for('error'), error.message]
      };
    }
  }
};

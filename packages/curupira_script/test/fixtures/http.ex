defmodule Fixtures.HTTP do
  @moduledoc """
  Test fixtures for HTTP client functionality.

  Tests translation of HTTP client calls to native fetch() API.
  """

  defmodule Response do
    @moduledoc """
    Represents an HTTP response.
    """
    defstruct [:status, :headers, :body, :ok?]
  end

  # Simple GET request
  def fetch_users do
    HTTP.get("https://api.example.com/users")
  end

  # GET with headers
  def fetch_with_auth do
    HTTP.get("https://api.example.com/data",
      headers: [{"Authorization", "Bearer token123"}]
    )
  end

  # POST with JSON body
  def create_user(name, email) do
    HTTP.post("https://api.example.com/users",
      body: "{\"name\":\"#{name}\",\"email\":\"#{email}\"}",
      headers: [{"Content-Type", "application/json"}]
    )
  end

  # PUT request
  def update_user(id, name) do
    HTTP.put("https://api.example.com/users/#{id}",
      body: "{\"name\":\"#{name}\"}",
      headers: [{"Content-Type", "application/json"}]
    )
  end

  # DELETE request
  def delete_user(id) do
    HTTP.delete("https://api.example.com/users/#{id}")
  end

  # Handle response with pattern matching
  def handle_response do
    case HTTP.get("https://api.example.com/users") do
      {:ok, %Response{status: 200, body: body}} ->
        {:ok, body}
      {:ok, %Response{status: status}} ->
        {:error, "HTTP #{status}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Handle response checking ok? field
  def handle_with_ok_check do
    case HTTP.get("https://api.example.com/users") do
      {:ok, %Response{ok?: true, body: body}} ->
        {:ok, body}
      {:ok, %Response{ok?: false, status: status}} ->
        {:error, status}
      {:error, reason} ->
        {:error, reason}
    end
  end

  # GET with multiple headers
  def fetch_with_multiple_headers do
    HTTP.get("https://api.example.com/data",
      headers: [
        {"Authorization", "Bearer token123"},
        {"Accept", "application/json"},
        {"User-Agent", "CurupiraScript/1.0"}
      ]
    )
  end

  # POST with empty options
  def create_without_body do
    HTTP.post("https://api.example.com/trigger")
  end

  # Generic request method
  def custom_request do
    HTTP.request("PATCH", "https://api.example.com/users/1",
      body: "{\"status\":\"active\"}",
      headers: [{"Content-Type", "application/json"}]
    )
  end
end

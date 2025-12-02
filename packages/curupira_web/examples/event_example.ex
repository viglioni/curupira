defmodule CurupiraWeb.Examples.EventExample do
  @moduledoc """
  Example demonstrating event handling with CurupiraWeb.

  This module shows how to:
  - Attach event listeners to DOM elements
  - Handle different event types (click, input, submit)
  - Use event utilities (preventDefault, getEventValue)
  - Build interactive UI with functional Elixir code

  ## Compilation

  To compile this example to JavaScript:

      mix curupira_js.build --input CurupiraWeb.Examples.EventExample --output priv/static/event_example.js

  Then include in HTML:

      <script src="event_example.js"></script>
      <script>CurupiraWeb.Examples.EventExample.main()</script>
  """

  alias CurupiraWeb.DOM

  @doc """
  Main entry point - sets up event handlers for a simple form.
  """
  def main do
    setup_click_counter()
    setup_input_logger()
    setup_form_handler()
  end

  @doc """
  Example: Click counter button

  HTML:
  ```html
  <button id="click-counter">Clicks: 0</button>
  ```
  """
  def setup_click_counter do
    case DOM.query_selector("#click-counter") do
      {:ok, button} ->
        # Attach click handler
        DOM.on_click(button, fn _event ->
          handle_click(button, 0)
        end)

      :error ->
        IO.puts("Click counter button not found")
    end
  end

  defp handle_click(button, count) do
    new_count = count + 1
    DOM.set_inner_text(button, "Clicks: #{new_count}")
  end

  @doc """
  Example: Input field that logs changes

  HTML:
  ```html
  <input id="name-input" type="text" placeholder="Enter your name">
  <div id="name-output"></div>
  ```
  """
  def setup_input_logger do
    case {DOM.query_selector("#name-input"), DOM.query_selector("#name-output")} do
      {{:ok, input}, {:ok, output}} ->
        # Attach input handler
        DOM.on_input(input, fn event ->
          case DOM.get_event_value(event) do
            {:ok, value} ->
              DOM.set_inner_text(output, "Hello, #{value}!")

            :error ->
              DOM.set_inner_text(output, "")
          end
        end)

      _ ->
        IO.puts("Input elements not found")
    end
  end

  @doc """
  Example: Form submission handler

  HTML:
  ```html
  <form id="contact-form">
    <input type="email" id="email" name="email" required>
    <button type="submit">Submit</button>
  </form>
  <div id="form-message"></div>
  ```
  """
  def setup_form_handler do
    case {DOM.query_selector("#contact-form"), DOM.query_selector("#form-message")} do
      {{:ok, form}, {:ok, message}} ->
        # Attach submit handler
        DOM.on_submit(form, fn event ->
          # Prevent default form submission
          DOM.prevent_default(event)

          # Get email value
          case DOM.query_selector("#email") do
            {:ok, email_input} ->
              case DOM.get_attribute(email_input, "value") do
                {:ok, email_value} ->
                  # Simulate form processing
                  DOM.set_inner_text(message, "Processing #{email_value}...")
                  # In real app: send to server here

                :error ->
                  DOM.set_inner_text(message, "Please enter an email")
              end

            :error ->
              DOM.set_inner_text(message, "Email field not found")
          end
        end)

      _ ->
        IO.puts("Form elements not found")
    end
  end

  @doc """
  Example: Keyboard event handler

  HTML:
  ```html
  <input id="search-box" type="text" placeholder="Search (Ctrl+Enter to submit)">
  ```
  """
  def setup_keyboard_handler do
    case DOM.query_selector("#search-box") do
      {:ok, search_box} ->
        DOM.on_keydown(search_box, fn event ->
          # Check for Ctrl+Enter
          if ctrl_enter?(event) do
            DOM.prevent_default(event)
            case DOM.get_event_value(event) do
              {:ok, query} -> perform_search(query)
              :error -> :ok
            end
          end
        end)

      :error ->
        IO.puts("Search box not found")
    end
  end

  defp ctrl_enter?(event) do
    # Note: In actual implementation, you'd check event.ctrlKey and event.key
    # This is a simplified example
    false
  end

  defp perform_search(query) do
    IO.puts("Searching for: #{query}")
  end

  @doc """
  Example: Mouse hover effects

  HTML:
  ```html
  <div id="hover-box" class="box">Hover over me!</div>
  ```
  """
  def setup_hover_effect do
    case DOM.query_selector("#hover-box") do
      {:ok, box} ->
        # Add hover class on mouse enter
        box = DOM.on_mouseenter(box, fn _event ->
          DOM.add_class(box, "hovered")
        end)

        # Remove hover class on mouse leave
        DOM.on_mouseleave(box, fn _event ->
          DOM.remove_class(box, "hovered")
        end)

      :error ->
        IO.puts("Hover box not found")
    end
  end

  @doc """
  Example: Focus/blur handlers for form validation

  HTML:
  ```html
  <input id="username" type="text" required>
  <span id="username-error" class="error"></span>
  ```
  """
  def setup_validation do
    case {DOM.query_selector("#username"), DOM.query_selector("#username-error")} do
      {{:ok, username}, {:ok, error}} ->
        # Validate on blur
        username = DOM.on_blur(username, fn event ->
          case DOM.get_event_value(event) do
            {:ok, value} when byte_size(value) < 3 ->
              DOM.set_inner_text(error, "Username must be at least 3 characters")
              DOM.add_class(username, "invalid")

            {:ok, _value} ->
              DOM.set_inner_text(error, "")
              DOM.remove_class(username, "invalid")

            :error ->
              :ok
          end
        end)

        # Clear error on focus
        DOM.on_focus(username, fn _event ->
          DOM.set_inner_text(error, "")
        end)

      _ ->
        IO.puts("Validation elements not found")
    end
  end
end

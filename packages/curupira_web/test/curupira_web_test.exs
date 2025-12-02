defmodule CurupiraWebTest do
  use ExUnit.Case
  doctest CurupiraWeb

  alias CurupiraWeb.DOM
  alias CurupiraWeb.DOM.{Element, Input, Button, Canvas, Form, Event}

  describe "CurupiraWeb" do
    test "returns version" do
      version = CurupiraWeb.version()
      assert is_binary(version)
    end
  end

  describe "DOM structs" do
    test "Element struct has correct fields" do
      element = %Element{
        tag_name: "div",
        id: "test",
        class_name: "container",
        __ref__: make_ref()
      }

      assert element.tag_name == "div"
      assert element.id == "test"
      assert element.class_name == "container"
      assert is_reference(element.__ref__)
    end

    test "Input struct has correct fields" do
      input = %Input{
        tag_name: "input",
        type: "text",
        placeholder: "Enter text",
        value: "",
        __ref__: make_ref()
      }

      assert input.tag_name == "input"
      assert input.type == "text"
      assert input.placeholder == "Enter text"
      assert is_reference(input.__ref__)
    end

    test "Button struct has correct fields" do
      button = %Button{
        tag_name: "button",
        type: "submit",
        disabled: false,
        __ref__: make_ref()
      }

      assert button.tag_name == "button"
      assert button.type == "submit"
      assert button.disabled == false
      assert is_reference(button.__ref__)
    end

    test "Canvas struct has correct fields" do
      canvas = %Canvas{
        tag_name: "canvas",
        width: 800,
        height: 600,
        __ref__: make_ref()
      }

      assert canvas.tag_name == "canvas"
      assert canvas.width == 800
      assert canvas.height == 600
      assert is_reference(canvas.__ref__)
    end

    test "Form struct has correct fields" do
      form = %Form{
        tag_name: "form",
        action: "/submit",
        method: "POST",
        __ref__: make_ref()
      }

      assert form.tag_name == "form"
      assert form.action == "/submit"
      assert form.method == "POST"
      assert is_reference(form.__ref__)
    end

    test "Event struct has correct fields" do
      event = %Event{
        type: "click",
        target: %Element{__ref__: make_ref()},
        current_target: %Element{__ref__: make_ref()},
        default_prevented: false,
        bubbles: true,
        cancelable: true,
        timestamp: System.system_time(:millisecond),
        __ref__: make_ref()
      }

      assert event.type == "click"
      assert is_struct(event.target, Element)
      assert is_struct(event.current_target, Element)
      assert event.default_prevented == false
      assert event.bubbles == true
      assert event.cancelable == true
      assert is_integer(event.timestamp)
      assert is_reference(event.__ref__)
    end
  end

  describe "DOM module" do
    test "DOM module defines FFI functions" do
      # Check that key functions are defined
      assert function_exported?(DOM, :query_selector, 1)
      assert function_exported?(DOM, :create_element, 1)
      assert function_exported?(DOM, :set_inner_text, 2)
      assert function_exported?(DOM, :append_child, 2)
      assert function_exported?(DOM, :add_class, 2)
      assert function_exported?(DOM, :remove_class, 2)
    end

    test "DOM module defines event handling functions" do
      # Check that event functions are defined
      assert function_exported?(DOM, :add_event_listener, 3)
      assert function_exported?(DOM, :remove_event_listener, 3)
      assert function_exported?(DOM, :on_click, 2)
      assert function_exported?(DOM, :on_change, 2)
      assert function_exported?(DOM, :on_input, 2)
      assert function_exported?(DOM, :on_submit, 2)
      assert function_exported?(DOM, :on_keydown, 2)
      assert function_exported?(DOM, :on_keyup, 2)
      assert function_exported?(DOM, :on_mouseenter, 2)
      assert function_exported?(DOM, :on_mouseleave, 2)
      assert function_exported?(DOM, :on_focus, 2)
      assert function_exported?(DOM, :on_blur, 2)
    end

    test "DOM module defines event utility functions" do
      # Check that event utilities are defined
      assert function_exported?(DOM, :prevent_default, 1)
      assert function_exported?(DOM, :stop_propagation, 1)
      assert function_exported?(DOM, :get_event_value, 1)
      assert function_exported?(DOM, :get_event_checked, 1)
    end

    test "DOM module defines style and dataset functions" do
      assert function_exported?(DOM, :set_style, 3)
      assert function_exported?(DOM, :set_styles, 2)
      assert function_exported?(DOM, :set_dataset, 3)
      assert function_exported?(DOM, :get_dataset, 2)
    end

    test "DOM module defines children manipulation functions" do
      assert function_exported?(DOM, :get_children, 1)
      assert function_exported?(DOM, :append_below, 2)
    end

    test "DOM module defines checkbox utility functions" do
      assert function_exported?(DOM, :get_checkbox_by_id, 1)
      assert function_exported?(DOM, :switch_checkbox, 2)
    end
  end

  # Note: EventExample tests are skipped as the example module
  # is in examples/ directory and compiled separately for documentation purposes
end

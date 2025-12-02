defmodule CurupiraWeb.DOM do
  @moduledoc """
  DOM manipulation module for CurupiraJS.

  Provides FFI bindings to browser DOM APIs with type-safe Elixir structs.

  ## Available Structs

  - `CurupiraWeb.DOM.Element` - Generic DOM element
  - `CurupiraWeb.DOM.Input` - Input element
  - `CurupiraWeb.DOM.Button` - Button element
  - `CurupiraWeb.DOM.Canvas` - Canvas element
  - `CurupiraWeb.DOM.Form` - Form element

  ## Example

      # Query and manipulate DOM
      {:ok, element} = DOM.query_selector("#app")
      updated = DOM.set_inner_text(element, "Hello, World!")
      {:ok, button} = DOM.create_element("button")
      button = DOM.set_attribute(button, "class", "btn-primary")
  """

  use CurupiraJS.FFI

  alias CurupiraWeb.DOM.Element

  # ===========================
  # DOM Query Methods
  # ===========================

  @doc """
  Find an element by CSS selector.

  Returns `{:ok, element}` if found, `{:error, :not_found}` otherwise.

  ## Example

      {:ok, element} = DOM.query_selector("#app")
      {:ok, element} = DOM.query_selector(".container")
      {:error, :not_found} = DOM.query_selector("#nonexistent")
  """
  ffi :query_selector,
    args: [:string],
    returns: {:option, Element.t()},
    wrapper: true,
    js: """
    (selector) => {
      const el = document.querySelector(selector);
      if (!el) return null;
      return {
        tag_name: el.tagName.toLowerCase(),
        id: el.id,
        class_name: el.className,
        inner_html: el.innerHTML,
        inner_text: el.innerText,
        value: el.value,
        __ref__: el
      };
    }
    """

  @doc """
  Find all elements matching a CSS selector.

  Returns a list of elements.

  ## Example

      elements = DOM.query_selector_all(".item")
      # Returns list of Element structs
  """
  ffi :query_selector_all,
    args: [:string],
    returns: :any,  # Returns array of elements
    wrapper: true,
    js: """
    (selector) => {
      const elements = document.querySelectorAll(selector);
      return Array.from(elements).map(el => ({
        tag_name: el.tagName.toLowerCase(),
        id: el.id,
        class_name: el.className,
        inner_html: el.innerHTML,
        inner_text: el.innerText,
        value: el.value,
        __ref__: el
      }));
    }
    """

  @doc """
  Find an element by its ID.

  Returns `{:ok, element}` if found, `{:error, :not_found}` otherwise.

  ## Example

      {:ok, element} = DOM.get_by_id("app")
  """
  ffi :get_by_id,
    args: [:string],
    returns: {:option, Element.t()},
    wrapper: true,
    js: """
    (id) => {
      const el = document.getElementById(id);
      if (!el) return null;
      return {
        tag_name: el.tagName.toLowerCase(),
        id: el.id,
        class_name: el.className,
        inner_html: el.innerHTML,
        inner_text: el.innerText,
        value: el.value,
        __ref__: el
      };
    }
    """

  # ===========================
  # DOM Creation Methods
  # ===========================

  @doc """
  Create a new DOM element with the given tag name.

  Returns `{:ok, element}`.

  ## Example

      {:ok, div} = DOM.create_element("div")
      {:ok, button} = DOM.create_element("button")
  """
  ffi :create_element,
    args: [:string],
    returns: {:ok, Element.t()},
    wrapper: true,
    js: """
    (tagName) => {
      const el = document.createElement(tagName);
      return {
        tag_name: tagName.toLowerCase(),
        id: el.id,
        class_name: el.className,
        inner_html: el.innerHTML,
        inner_text: el.innerText,
        value: el.value,
        __ref__: el
      };
    }
    """

  # ===========================
  # DOM Manipulation Methods
  # ===========================

  @doc """
  Set the inner HTML of an element.

  Returns the updated element struct.

  ## Example

      element = DOM.set_inner_html(element, "<p>Hello</p>")
  """
  ffi :set_inner_html,
    args: [Element.t(), :string],
    returns: Element.t(),
    wrapper: true,
    js: """
    (element, html) => {
      element.__ref__.innerHTML = html;
      return { ...element, inner_html: html, inner_text: element.__ref__.innerText };
    }
    """

  @doc """
  Set the inner text of an element.

  Returns the updated element struct.

  ## Example

      element = DOM.set_inner_text(element, "Hello, World!")
  """
  ffi :set_inner_text,
    args: [Element.t(), :string],
    returns: Element.t(),
    wrapper: true,
    js: """
    (element, text) => {
      element.__ref__.innerText = text;
      return { ...element, inner_text: text, inner_html: element.__ref__.innerHTML };
    }
    """

  @doc """
  Set an attribute on an element.

  Returns the updated element struct.

  ## Example

      element = DOM.set_attribute(element, "data-id", "123")
      element = DOM.set_attribute(element, "class", "btn btn-primary")
  """
  ffi :set_attribute,
    args: [Element.t(), :string, :string],
    returns: Element.t(),
    wrapper: true,
    js: """
    (element, name, value) => {
      element.__ref__.setAttribute(name, value);
      const updated = { ...element };
      if (name === 'id') updated.id = value;
      if (name === 'class') updated.class_name = value;
      return updated;
    }
    """

  @doc """
  Get an attribute from an element.

  Returns `{:ok, value}` if the attribute exists, `{:error, :not_found}` otherwise.

  ## Example

      {:ok, "123"} = DOM.get_attribute(element, "data-id")
      {:error, :not_found} = DOM.get_attribute(element, "nonexistent")
  """
  ffi :get_attribute,
    args: [Element.t(), :string],
    returns: {:option, :string},
    wrapper: true,
    js: """
    (element, name) => {
      return element.__ref__.getAttribute(name);
    }
    """

  @doc """
  Add a CSS class to an element.

  Returns the updated element struct.

  ## Example

      element = DOM.add_class(element, "active")
  """
  ffi :add_class,
    args: [Element.t(), :string],
    returns: Element.t(),
    wrapper: true,
    js: """
    (element, className) => {
      element.__ref__.classList.add(className);
      return { ...element, class_name: element.__ref__.className };
    }
    """

  @doc """
  Remove a CSS class from an element.

  Returns the updated element struct.

  ## Example

      element = DOM.remove_class(element, "active")
  """
  ffi :remove_class,
    args: [Element.t(), :string],
    returns: Element.t(),
    wrapper: true,
    js: """
    (element, className) => {
      element.__ref__.classList.remove(className);
      return { ...element, class_name: element.__ref__.className };
    }
    """

  @doc """
  Toggle a CSS class on an element.

  Returns the updated element struct.

  ## Example

      element = DOM.toggle_class(element, "active")
  """
  ffi :toggle_class,
    args: [Element.t(), :string],
    returns: Element.t(),
    wrapper: true,
    js: """
    (element, className) => {
      element.__ref__.classList.toggle(className);
      return { ...element, class_name: element.__ref__.className };
    }
    """

  # ===========================
  # DOM Tree Manipulation
  # ===========================

  @doc """
  Append a child element to a parent element.

  Returns the updated parent element.

  ## Example

      parent = DOM.append_child(parent, child)
  """
  ffi :append_child,
    args: [Element.t(), Element.t()],
    returns: Element.t(),
    wrapper: true,
    js: """
    (parent, child) => {
      parent.__ref__.appendChild(child.__ref__);
      return { ...parent, inner_html: parent.__ref__.innerHTML };
    }
    """

  @doc """
  Remove an element from its parent.

  Returns the removed element.

  ## Example

      element = DOM.remove(element)
  """
  ffi :remove,
    args: [Element.t()],
    returns: Element.t(),
    wrapper: true,
    js: """
    (element) => {
      element.__ref__.remove();
      return element;
    }
    """
end

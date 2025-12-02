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
    returns: {:option, :any},
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
    returns: {:option, :any},
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
    returns: {:ok, :any},
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
    args: [:any, :string],
    returns: :any,
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
    args: [:any, :string],
    returns: :any,
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
    args: [:any, :string, :string],
    returns: :any,
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
    args: [:any, :string],
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
    args: [:any, :string],
    returns: :any,
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
    args: [:any, :string],
    returns: :any,
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
    args: [:any, :string],
    returns: :any,
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
    args: [:any, :any],
    returns: :any,
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
    args: [:any],
    returns: :any,
    wrapper: true,
    js: """
    (element) => {
      element.__ref__.remove();
      return element;
    }
    """

  @doc """
  Insert an element below (after) a reference element.

  Returns the reference element.

  ## Example

      element = DOM.append_below(element, new_element)
  """
  ffi :append_below,
    args: [:any, :any],
    returns: :any,
    wrapper: true,
    js: """
    (referenceElement, newElement) => {
      referenceElement.__ref__.parentNode?.insertBefore(
        newElement.__ref__,
        referenceElement.__ref__.nextSibling
      );
      return referenceElement;
    }
    """

  @doc """
  Get all children of an element.

  Returns a list of child elements.

  ## Example

      children = DOM.get_children(parent)
  """
  ffi :get_children,
    args: [:any],
    returns: :any,  # Returns array of elements
    wrapper: true,
    js: """
    (element) => {
      return Array.from(element.__ref__.children).map(child => ({
        tag_name: child.tagName.toLowerCase(),
        id: child.id,
        class_name: child.className,
        inner_html: child.innerHTML,
        inner_text: child.innerText,
        value: child.value,
        __ref__: child
      }));
    }
    """

  # ===========================
  # getElementsByTagName
  # ===========================

  @doc """
  Get all elements with the given tag name.

  Returns a list of elements.

  ## Example

      divs = DOM.get_elements_by_tag_name("div")
      buttons = DOM.get_elements_by_tag_name("button")
  """
  ffi :get_elements_by_tag_name,
    args: [:string],
    returns: :any,  # Returns array of elements
    wrapper: true,
    js: """
    (tagName) => {
      return Array.from(document.getElementsByTagName(tagName)).map(el => ({
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

  # ===========================
  # Style Manipulation
  # ===========================

  @doc """
  Set a CSS style property on an element.

  Returns the updated element.

  ## Example

      element = DOM.set_style(element, "color", "red")
      element = DOM.set_style(element, "backgroundColor", "blue")
  """
  ffi :set_style,
    args: [:any, :string, :string],
    returns: :any,
    wrapper: true,
    js: """
    (element, property, value) => {
      element.__ref__.style[property] = value;
      return element;
    }
    """

  @doc """
  Set multiple style properties at once.

  Takes a map of property names to values.

  Returns the updated element.

  ## Example

      # Note: This will be called from JS with an object
      # In generated JS: setStyles(element, {color: "red", fontSize: "16px"})
  """
  ffi :set_styles,
    args: [:any, :any],  # :any for JS object
    returns: :any,
    wrapper: true,
    js: """
    (element, styles) => {
      Object.assign(element.__ref__.style, styles);
      return element;
    }
    """

  # ===========================
  # Dataset (data-* attributes)
  # ===========================

  @doc """
  Set a data-* attribute on an element.

  Returns the updated element.

  ## Example

      element = DOM.set_dataset(element, "userId", "123")
      # Sets data-user-id="123"
  """
  ffi :set_dataset,
    args: [:any, :string, :string],
    returns: :any,
    wrapper: true,
    js: """
    (element, key, value) => {
      element.__ref__.dataset[key] = value;
      return element;
    }
    """

  @doc """
  Get a data-* attribute from an element.

  Returns `{:ok, value}` if exists, `{:error, :not_found}` otherwise.

  ## Example

      {:ok, "123"} = DOM.get_dataset(element, "userId")
  """
  ffi :get_dataset,
    args: [:any, :string],
    returns: {:option, :string},
    wrapper: true,
    js: """
    (element, key) => {
      return element.__ref__.dataset[key] || null;
    }
    """

  # ===========================
  # Checkbox Helpers
  # ===========================

  @doc """
  Get a checkbox input by ID.

  Returns `{:ok, element}` if the element exists and is a checkbox,
  `{:error, :not_found}` otherwise.

  ## Example

      {:ok, checkbox} = DOM.get_checkbox_by_id("agree-terms")
  """
  ffi :get_checkbox_by_id,
    args: [:string],
    returns: {:option, :any},
    wrapper: true,
    js: """
    (id) => {
      const element = document.getElementById(id);
      if (!element || !(element instanceof HTMLInputElement) || element.type !== 'checkbox') {
        return null;
      }
      return {
        tag_name: element.tagName.toLowerCase(),
        id: element.id,
        class_name: element.className,
        value: element.value,
        __ref__: element
      };
    }
    """

  @doc """
  Toggle a checkbox's checked state, or set it to a specific value.

  If `state` is provided, sets the checkbox to that state.
  If `state` is nil, toggles the current state.

  Returns `:ok`.

  ## Example

      :ok = DOM.switch_checkbox("agree", true)   # Check it
      :ok = DOM.switch_checkbox("agree", false)  # Uncheck it
      :ok = DOM.switch_checkbox("agree", nil)    # Toggle it
  """
  ffi :switch_checkbox,
    args: [:string, :any],  # id, state (boolean or null)
    returns: :ok,
    js: """
    (id, state) => {
      const checkbox = document.getElementById(id);
      if (!checkbox || !(checkbox instanceof HTMLInputElement) || checkbox.type !== 'checkbox') {
        return Symbol.for('ok');
      }
      if (state === null || state === undefined) {
        checkbox.checked = !checkbox.checked;
      } else {
        checkbox.checked = state;
      }
      return Symbol.for('ok');
    }
    """

  # ===========================
  # Scroll Helpers
  # ===========================

  @doc """
  Scroll smoothly to an element.

  Returns `:ok`.

  ## Example

      :ok = DOM.scroll_to(element)
  """
  ffi :scroll_to,
    args: [:any],
    returns: :ok,
    wrapper: true,
    js: """
    (element) => {
      element.__ref__.scrollIntoView({ behavior: 'smooth' });
      return Symbol.for('ok');
    }
    """

  # ===========================
  # Advanced innerHTML helpers
  # ===========================

  @doc """
  Edit innerHTML by applying a transformation function.

  Note: In the generated JavaScript, you'll pass a function that transforms the HTML string.

  Returns the updated element.

  ## Example (in generated JS)

      // Transform existing HTML
      editInnerHtmlWithFn(element, (html) => html.toUpperCase())
  """
  ffi :edit_inner_html_with_fn,
    args: [:any, :any],  # element, function
    returns: :any,
    wrapper: true,
    js: """
    (element, fn) => {
      const newHtml = fn(element.__ref__.innerHTML);
      element.__ref__.innerHTML = newHtml;
      return {
        ...element,
        inner_html: newHtml,
        inner_text: element.__ref__.innerText
      };
    }
    """

  # ===========================
  # Utility Functions
  # ===========================

  @doc """
  Check if an element has a CSS class.

  Returns `true` if the element has the class, `false` otherwise.

  ## Example

      true = DOM.has_class?(element, "active")
  """
  ffi :has_class?,
    args: [:any, :string],
    returns: :any,  # boolean
    wrapper: true,
    js: """
    (element, className) => {
      return element.__ref__.classList.contains(className);
    }
    """

  @doc """
  Get all classes from an element as a list.

  Returns a list of class names.

  ## Example

      ["btn", "btn-primary", "active"] = DOM.get_class_list(element)
  """
  ffi :get_class_list,
    args: [:any],
    returns: :any,  # array of strings
    wrapper: true,
    js: """
    (element) => {
      return Array.from(element.__ref__.classList);
    }
    """

  @doc """
  Add multiple CSS classes to an element.

  Takes a list of class names.

  Returns the updated element.

  ## Example (in generated JS)

      addClasses(element, ["btn", "btn-primary", "active"])
  """
  ffi :add_classes,
    args: [:any, :any],  # element, array of strings
    returns: :any,
    wrapper: true,
    js: """
    (element, classNames) => {
      classNames.forEach(cls => element.__ref__.classList.add(cls));
      return { ...element, class_name: element.__ref__.className };
    }
    """

  @doc """
  Focus an element.

  Returns `:ok`.

  ## Example

      :ok = DOM.focus(input_element)
  """
  ffi :focus,
    args: [:any],
    returns: :ok,
    wrapper: true,
    js: """
    (element) => {
      element.__ref__.focus();
      return Symbol.for('ok');
    }
    """

  @doc """
  Blur (unfocus) an element.

  Returns `:ok`.

  ## Example

      :ok = DOM.blur(input_element)
  """
  ffi :blur,
    args: [:any],
    returns: :ok,
    wrapper: true,
    js: """
    (element) => {
      element.__ref__.blur();
      return Symbol.for('ok');
    }
    """

  # ===========================
  # Event Handling
  # ===========================

  @doc """
  Add an event listener to an element.

  The handler should be a JavaScript function that accepts an event parameter.
  In compiled Elixir code, this will be an Elixir function that gets compiled to JS.

  Returns the element.

  ## Example (in compiled Elixir code)

      # Define handler function
      def handle_click(event) do
        # event is a JS event object
        # In real usage, you'd interact with it via FFI
        :ok
      end

      # Register the handler (this compiles to JS)
      element = DOM.add_event_listener(element, "click", &handle_click/1)

  ## Example (direct in generated JS)

      addEventListener(element, "click", (event) => {
        console.log("Clicked!", event);
      })
  """
  ffi :add_event_listener,
    args: [:any, :string, :any],  # element, event_name, handler_function
    returns: :any,
    wrapper: true,
    js: """
    (element, eventName, handler) => {
      element.__ref__.addEventListener(eventName, handler);
      return element;
    }
    """

  @doc """
  Remove an event listener from an element.

  The handler must be the same function reference that was passed to add_event_listener.

  Returns the element.

  ## Example

      element = DOM.remove_event_listener(element, "click", handler)
  """
  ffi :remove_event_listener,
    args: [:any, :string, :any],  # element, event_name, handler_function
    returns: :any,
    wrapper: true,
    js: """
    (element, eventName, handler) => {
      element.__ref__.removeEventListener(eventName, handler);
      return element;
    }
    """

  @doc """
  Add a click event listener to an element.

  Convenience wrapper around add_event_listener for click events.

  Returns the element.

  ## Example

      element = DOM.on_click(button, handler)
  """
  ffi :on_click,
    args: [:any, :any],  # element, handler
    returns: :any,
    wrapper: true,
    js: """
    (element, handler) => {
      element.__ref__.addEventListener('click', handler);
      return element;
    }
    """

  @doc """
  Add a change event listener to an element.

  Typically used for inputs, selects, and textareas.

  Returns the element.

  ## Example

      input = DOM.on_change(input, handler)
  """
  ffi :on_change,
    args: [:any, :any],
    returns: :any,
    wrapper: true,
    js: """
    (element, handler) => {
      element.__ref__.addEventListener('change', handler);
      return element;
    }
    """

  @doc """
  Add an input event listener to an element.

  Fires on every keystroke/input change.

  Returns the element.

  ## Example

      input = DOM.on_input(input, handler)
  """
  ffi :on_input,
    args: [:any, :any],
    returns: :any,
    wrapper: true,
    js: """
    (element, handler) => {
      element.__ref__.addEventListener('input', handler);
      return element;
    }
    """

  @doc """
  Add a submit event listener to a form.

  Returns the element.

  ## Example

      form = DOM.on_submit(form, handler)
  """
  ffi :on_submit,
    args: [:any, :any],
    returns: :any,
    wrapper: true,
    js: """
    (element, handler) => {
      element.__ref__.addEventListener('submit', handler);
      return element;
    }
    """

  @doc """
  Add a keydown event listener to an element.

  Returns the element.

  ## Example

      input = DOM.on_keydown(input, handler)
  """
  ffi :on_keydown,
    args: [:any, :any],
    returns: :any,
    wrapper: true,
    js: """
    (element, handler) => {
      element.__ref__.addEventListener('keydown', handler);
      return element;
    }
    """

  @doc """
  Add a keyup event listener to an element.

  Returns the element.

  ## Example

      input = DOM.on_keyup(input, handler)
  """
  ffi :on_keyup,
    args: [:any, :any],
    returns: :any,
    wrapper: true,
    js: """
    (element, handler) => {
      element.__ref__.addEventListener('keyup', handler);
      return element;
    }
    """

  @doc """
  Add a mouseenter event listener to an element.

  Fires when the mouse enters the element.

  Returns the element.

  ## Example

      div = DOM.on_mouseenter(div, handler)
  """
  ffi :on_mouseenter,
    args: [:any, :any],
    returns: :any,
    wrapper: true,
    js: """
    (element, handler) => {
      element.__ref__.addEventListener('mouseenter', handler);
      return element;
    }
    """

  @doc """
  Add a mouseleave event listener to an element.

  Fires when the mouse leaves the element.

  Returns the element.

  ## Example

      div = DOM.on_mouseleave(div, handler)
  """
  ffi :on_mouseleave,
    args: [:any, :any],
    returns: :any,
    wrapper: true,
    js: """
    (element, handler) => {
      element.__ref__.addEventListener('mouseleave', handler);
      return element;
    }
    """

  @doc """
  Add a focus event listener to an element.

  Returns the element.

  ## Example

      input = DOM.on_focus(input, handler)
  """
  ffi :on_focus,
    args: [:any, :any],
    returns: :any,
    wrapper: true,
    js: """
    (element, handler) => {
      element.__ref__.addEventListener('focus', handler);
      return element;
    }
    """

  @doc """
  Add a blur event listener to an element.

  Returns the element.

  ## Example

      input = DOM.on_blur(input, handler)
  """
  ffi :on_blur,
    args: [:any, :any],
    returns: :any,
    wrapper: true,
    js: """
    (element, handler) => {
      element.__ref__.addEventListener('blur', handler);
      return element;
    }
    """

  # ===========================
  # Event Utilities
  # ===========================

  @doc """
  Prevent the default action of an event.

  Call this within an event handler to prevent default behavior
  (e.g., prevent form submission, prevent link navigation).

  Returns `:ok`.

  ## Example (in JS)

      on_click(button, (event) => {
        preventDefault(event);
        // Handle click without default action
      })
  """
  ffi :prevent_default,
    args: [:any],  # event object
    returns: :ok,
    js: """
    (event) => {
      event.preventDefault();
      return Symbol.for('ok');
    }
    """

  @doc """
  Stop event propagation (bubbling).

  Prevents the event from bubbling up to parent elements.

  Returns `:ok`.

  ## Example

      on_click(child, (event) => {
        stopPropagation(event);
        // Event won't bubble to parent
      })
  """
  ffi :stop_propagation,
    args: [:any],
    returns: :ok,
    js: """
    (event) => {
      event.stopPropagation();
      return Symbol.for('ok');
    }
    """

  @doc """
  Get the value from an event target.

  Useful for getting input values in change/input handlers.

  Returns `{:ok, value}` if the target has a value, `{:error, :not_found}` otherwise.

  ## Example

      on_change(input, (event) => {
        const value = getEventValue(event);
        // Use value...
      })
  """
  ffi :get_event_value,
    args: [:any],  # event object
    returns: {:option, :string},
    js: """
    (event) => {
      return event.target?.value || null;
    }
    """

  @doc """
  Get the checked state from an event target.

  Useful for checkbox/radio change handlers.

  Returns the checked boolean.

  ## Example

      on_change(checkbox, (event) => {
        const checked = getEventChecked(event);
        // Use checked state...
      })
  """
  ffi :get_event_checked,
    args: [:any],
    returns: :any,  # boolean
    js: """
    (event) => {
      return event.target?.checked || false;
    }
    """
end

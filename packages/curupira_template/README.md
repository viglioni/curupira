# Curupira Template

Mix template for creating client-side applications with CurupiraJS.

## What is CurupiraJS?

CurupiraJS is an Elixir-to-JavaScript compiler that lets you write frontend applications in Elixir. It includes:

- **curupira_js** - Elixir to JavaScript transpiler
- **curupira_web** - DOM manipulation and browser APIs

## Installation

Add the template to your Mix installation:

```bash
mix archive.install hex mix_templates
mix template.install hex curupira
```

Or install from source:

```bash
cd packages/curupira_template
mix deps.get
mix template.install
```

## Usage

Create a new CurupiraJS project:

```bash
mix template curupira my_app
cd my_app
```

Follow the instructions in the generated `readme.org` file.

## Quick Start

```bash
# Create new project
mix template curupira my_awesome_app
cd my_awesome_app

# Install dependencies
mix deps.get

# Build JavaScript
mix curupira_js.build

# Serve the HTML (using Python)
python3 -m http.server 8000

# Open http://localhost:8000/html/ in your browser
```

## What's Included

The template generates:

- **lib/my_app.ex** - Main application module with example DOM manipulation
- **html/index.html** - HTML page with styles and JavaScript loader
- **mix.exs** - Project configuration with curupira_js and curupira_web
- **readme.org** - Detailed usage instructions
- **test/** - Test structure

## Example Code

The generated app includes a working example:

```elixir
defmodule MyApp do
  alias CurupiraWeb.DOM

  def main do
    {:ok, app} = DOM.query_selector("#app")

    {:ok, button} = DOM.create_element("button")
    button = DOM.set_inner_text(button, "Click me!")
    button = DOM.on_click(button, fn _event ->
      IO.puts("Button clicked!")
    end)

    DOM.append_child(app, button)
  end
end
```

## Requirements

- Elixir 1.17+
- Mix templates (automatically installed)

## Development

The template uses local path dependencies to curupira_js and curupira_web, so it's ready to use within the monorepo.

## License

MIT

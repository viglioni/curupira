# Curupira - Context for Claude Code

**Last Updated:** 2025-11-27
**Project Status:** Phase 0 - Foundation & Planning

---

## 🎯 Project Mission

Build a **modern Elixir-to-JavaScript transpiler** for client-side web applications, enabling developers to write frontend code in Elixir instead of JavaScript/TypeScript.

**Key Goal:** Fork and modernize ElixirScript (abandoned in 2018) to support Elixir 1.17+ with modern features.

---

## 📁 Repository Structure

This is a **monorepo** with three independent packages:

```
curupira/
├── packages/
│   ├── curupira_script/     # Core transpiler (Elixir → JS)
│   │   └── PRIORITY: Fork ElixirScript here
│   ├── curupira_web/        # Browser/Web APIs wrapper
│   │   └── STATUS: Not started
│   └── curupira_template/   # Mix template generator
│       └── STATUS: Working (uses old ElixirScript 0.32)
├── examples/                # Example apps (to be created)
├── docs/                    # Documentation
├── .llm/                    # This directory - Claude context
│   ├── claude.md           # This file
│   ├── design.org          # Comprehensive design doc
│   └── decisions.org       # Architecture decisions
└── readme.org              # Main README
```

### Important Files to Read

1. **[design.org](.llm/design.org)** - Comprehensive technical design (MUST READ)
2. **[decisions.org](.llm/decisions.org)** - Key architecture decisions with rationale
3. **[readme.org](../readme.org)** - Project overview
4. **[packages/curupira_script/]** - Where we'll fork ElixirScript

---

## 🏗️ What is Curupira?

### The Problem

- **ElixirScript** (2018): Great idea, but abandoned. Only supports Elixir 1.6.
- **Phoenix LiveView** (2024): Server-side only, not for client-side SPAs.
- **Gap**: No way to write modern client-side Elixir apps.

### Our Solution

**Curupira** = ElixirScript (proven architecture) + Modern Elixir (1.17+) + Active maintenance

```elixir
# You write Elixir
defmodule MyApp do
  def greet(name) do
    "Hello, #{name}!"
  end

  def process(items) do
    items
    |> Enum.map(&String.upcase/1)
    |> Enum.join(", ")
  end
end
```

```javascript
// Curupira generates clean JavaScript
export default {
  greet(name) {
    return `Hello, ${name}!`;
  },

  process(items) {
    return Elixir.Enum.join(
      Elixir.Enum.map(items, x => Elixir.String.upcase(x)),
      ", "
    );
  }
};
```

---

## 🎭 The Three Packages

### 1. curupira_script (Priority 1)

**What:** Elixir → JavaScript transpiler
**Status:** 🚧 Not started (needs ElixirScript fork)
**Version:** 0.33.0-dev

**Current Task:** Fork ElixirScript codebase into `packages/curupira_script/`

**Key Components:**
- Compiler pipeline (AST extraction → translation → JS generation)
- JavaScript runtime library (Enum, String, Map, etc.)
- Mix compiler integration

### 2. curupira_web (Priority 3)

**What:** Browser API wrappers (DOM, Console, Fetch, etc.)
**Status:** ⏳ Planned (after curupira_script works)
**Version:** 0.3.0-dev

Will provide:
```elixir
Console.log("Hello!")
Document.query_selector("#app")
Fetch.get("/api/users")
```

### 3. curupira_template (Working!)

**What:** Mix template for scaffolding projects
**Status:** ✅ Working (uses old ElixirScript 0.32.1)
**Version:** 1.0.0
**Location:** `packages/curupira_template/`

**Already functional:**
```bash
mix gen curupira my_app
cd my_app
mix watch.compile  # Auto-compile Elixir → JS + webpack dev server
```

---

## 🗺️ Development Roadmap

### Phase 0: Architecture Study (Current - Week 1-4)

**Goal:** Deeply understand ElixirScript before building fresh implementation

**Strategy Change:** After discussion, we decided to study ElixirScript thoroughly, then build a fresh implementation while stealing the hard parts (pattern matching, type definitions). This gives us:
- ✅ Clean, modern codebase
- ✅ Deep understanding before coding
- ✅ Reuse proven solutions (Tailored library)
- ✅ ElixirScript tests validate behavior

**Tasks:**
- [ ] **Clone ElixirScript as reference**
  - Source: https://github.com/elixirscript/elixirscript
  - Clone into `packages/curupira_script/reference/`
  - Run their test suite locally
- [ ] **Document architecture** in `.llm/elixirscript-study.org`
  - BEAM AST extraction (how debug_info works)
  - Translation pipeline (passes, AST → ESTree)
  - Pattern matching (Tailored library)
  - Hard problems & solutions (trampolining, protocols)
- [ ] **Map modern features** to implementation approach
  - Stepped ranges, Duration, JSON
  - How to implement each
- [ ] **Create implementation plan**
  - What to steal (Tailored, types, tests)
  - What to rebuild (compiler, runtime)
  - Project structure

### Phase 1: Greenfield Build (Week 5-8)

**Goal:** Build fresh implementation using ElixirScript as reference

**What to Steal:**
- Pattern matching library (Tailored) - don't reinvent
- Type definitions (Tuple, BitString classes) - working
- Test suite - validate our output matches theirs
- Trampolining, protocol dispatch - solved problems

**What to Build Fresh:**
- Compiler pipeline (modern Elixir patterns)
- Mix integration (modern `Mix.Task.Compiler`)
- AST translation (cleaner code)
- Runtime stdlib (modern JS)

**Initial Target:** Compile one simple module to JS

### Phase 2: Modern Elixir Syntax (Week 9-12)

**Goal:** Support Elixir 1.12-1.17 features

**High Priority:**
1. **Stepped ranges** (1.12): `1..10//2`
2. **then/tap** (1.12): `value |> tap(&IO.inspect/1)`
3. **is_non_struct_map/1** (1.17): New guard
4. **Duration type** (1.17): `Duration.new!(hour: 1)`

### Phase 2: Standard Library (Week 7-12)

Expand from ~20% to ~30% stdlib coverage:
- More Enum functions (product, zip_with, frequencies, etc.)
- JSON module (NEW in Elixir 1.18)
- More String/Map functions
- Date/Time shifting functions

### Phase 3: Developer Experience (Week 13-16)

- Better error messages
- Source maps
- Incremental compilation
- Fast watch mode

### Phase 4+: Advanced Features (Week 17+)

- Protocol improvements
- Better Agent support
- CLI tool
- TypeScript definitions

---

## 🧭 Key Technical Decisions

### ✅ What We Decided

1. **Fork ElixirScript, don't rewrite**
   - 80% of work is done
   - Proven architecture
   - Working test suite
   - Faster to market (3-4 months vs 18-24 months)

2. **ES Modules only**
   - Drop CommonJS/UMD support
   - Simpler codebase
   - Modern standard

3. **Use BEAM debug_info for AST**
   - Macros pre-expanded
   - Same AST Elixir compiler uses
   - Reliable

4. **Pattern matching via runtime library**
   - Keep using Tailored (or similar)
   - Easier than compiling to JS conditionals

5. **No OTP support**
   - Client-side doesn't need GenServer/Supervisor
   - Massively reduces scope
   - Can add later if needed

6. **Monorepo with independent versions**
   - Tag format: `curupira_script-v0.33.0`
   - Each package published separately to Hex
   - Users only download what they need

### ❌ What We Rejected

- **Rewrite from scratch**: Too slow, too risky
- **Multiple output formats**: ES Modules sufficient
- **Full OTP support**: Not needed for client-side
- **100% stdlib coverage**: Diminishing returns

See [decisions.org](.llm/decisions.org) for detailed rationale.

---

## 🏛️ Architecture Overview

### Compilation Pipeline

```
Entry Modules (mix.exs config)
    ↓
Find Used Modules (recursive dependency crawl)
    ↓
Extract AST from BEAM files (debug_info)
    ↓
Find Used Functions (tree-shaking)
    ↓
Translate to ESTree (JavaScript AST)
    ↓
Generate JavaScript Code
    ↓
Write ES Modules (one .js file per Elixir module)
```

### Key Components

**Elixir Side (Compiler):**
```
lib/curupira_script/
├── compiler.ex              # Orchestrates pipeline
├── beam.ex                  # BEAM AST extraction
├── state.ex                 # Compilation state (ETS)
└── passes/
    ├── find_used_modules.ex
    ├── find_used_functions.ex
    ├── translate.ex         # Elixir AST → ESTree
    └── output.ex            # ESTree → JS code
```

**JavaScript Side (Runtime):**
```
priv/javascript/lib/
├── core.js        # Kernel functions (is_atom, length, etc.)
├── pattern.js     # Pattern matching engine
├── types.js       # Tuple, BitString, Range, Duration
├── enum.js        # Enum module
├── string.js      # String module
├── map.js         # Map module
└── json.js        # JSON module (NEW)
```

### Data Type Mapping

| Elixir | JavaScript |
|--------|-----------|
| `42` | `42` |
| `3.14` | `3.14` |
| `"hello"` | `"hello"` |
| `:atom` | `Symbol.for("atom")` |
| `[1, 2, 3]` | `Object.freeze([1, 2, 3])` |
| `%{a: 1}` | `new Map([[Symbol.for("a"), 1]])` |
| `{:ok, val}` | `new Tuple(Symbol.for("ok"), val)` |

---

## 🔧 Common Development Tasks

### Setting Up for Development

```bash
cd /Users/laura/personal/curupira

# Work on curupira_script (when we have the code)
cd packages/curupira_script
mix deps.get
mix test

# Work on curupira_template (already exists)
cd packages/curupira_template
mix deps.get
mix template.install
```

### Testing the Template

```bash
cd packages/curupira_template
mix template.install

cd /tmp
mix gen curupira test_app
cd test_app
mix deps.get
npm install
mix watch.compile
```

### Running Tests

```bash
# Elixir tests
mix test

# JavaScript runtime tests (when available)
cd priv/javascript
npm test
```

---

## 📝 File Conventions

### Documentation Format

**IMPORTANT:** This project uses **Org mode** (`.org` files), not Markdown!

- ✅ `readme.org`, `design.org`, `decisions.org`
- ❌ `README.md`, `DESIGN.md`, `decisions.md`

**Why:** Team uses Emacs. Org mode is superior for technical docs.

**Exception:** This file (`.llm/claude.md`) is Markdown because it's for Claude Code's context system.

### Code Style

**Elixir:**
- Standard Elixir formatter (`mix format`)
- 2-space indentation
- Follow [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide)

**JavaScript:**
- ES2020+ syntax
- Prefer `const` over `let`
- Use arrow functions
- Standard ESLint rules

---

## 🚨 Important Context

### ElixirScript History

**ElixirScript** (2015-2018):
- Created by Bryan Joseph
- Last release: v0.32.1 (March 2018)
- Supports Elixir 1.6 only
- ~10,000 lines of compiler code
- ~3,000 lines of JS runtime
- Abandoned but functional

**Why it stopped:**
- Maintaining AST compatibility is hard
- Stdlib coverage is massive work
- OTP support is extremely complex
- Limited real-world adoption

**What we learned:**
- Core architecture is solid
- Focus on common use cases, not 100% coverage
- Incremental enhancement beats rewrite
- Active maintenance is critical

### Elixir Version History (Relevant Features)

**1.7-1.11:** Exception improvements, mix compile improvements

**1.12 (2021):**
- Stepped ranges: `1..10//2`
- `Enum.product/1`, `Enum.zip_with/2`
- `then/2` and `tap/2`

**1.13-1.16:** Mix improvements, compiler optimizations

**1.17 (2024-06):**
- **Set-theoretic types** (compile-time, can ignore)
- **Duration type** - NEW data type!
- `Date.shift/2`, `Time.shift/2`, `DateTime.shift/2`
- `is_non_struct_map/1` guard
- Erlang/OTP 27 support

**1.18 (2024-12):**
- **JSON module** - Built-in JSON!
- Type checking improvements
- ExUnit parameterized tests

**1.19 (2025):**
- Even better type inference
- Compiler optimizations

### What Curupira Must Support

**Minimum (Phase 0-1):**
- Elixir 1.17+ language features
- Core data types
- Basic Kernel functions
- Pattern matching
- Common Enum/String/Map functions

**Target (Phase 2-3):**
- Stepped ranges, Duration, JSON
- 30% stdlib coverage
- Good error messages
- Fast compilation

**Nice to Have (Phase 4+):**
- Protocols
- Agent
- TypeScript definitions
- 50%+ stdlib coverage

---

## 🎓 Key Learnings from ElixirScript

### What Worked Well

1. **BEAM debug_info extraction** - Brilliant! No macro expansion needed.
2. **ESTree output** - Standard JS AST format, works with all tools.
3. **One file per module** - Good for tree-shaking and debugging.
4. **Pattern matching library** - Easier than compiling to conditionals.
5. **Symbol.for() for atoms** - Perfect fit.

### What Was Hard

1. **Stdlib coverage** - Elixir stdlib is huge. Can't do it all.
2. **OTP** - Process model is massive work, limited value for client-side.
3. **Keeping up with Elixir** - Language evolves fast.
4. **Performance** - JS is slower than BEAM, especially for recursion.
5. **Debugging** - Stack traces don't match Elixir code.

### Our Strategy

- ✅ Keep what worked (architecture)
- ✅ Focus on 30% stdlib (Pareto principle)
- ✅ Skip OTP (not needed)
- ✅ Active maintenance (don't let it rot)
- ✅ Better DX (errors, source maps, speed)

---

## 🤖 How to Help Me (Claude) Most

### When Starting a Task

1. **Tell me the phase/goal**: "We're in Phase 0, forking ElixirScript"
2. **Point to relevant docs**: "Check design.org section X"
3. **Specify package**: "Work in packages/curupira_script/"
4. **Give context**: "This adds Duration type from Elixir 1.17"

### When I'm Stuck

1. **Check design.org first** - Most technical questions answered there
2. **Check decisions.org** - Explains "why" we chose something
3. **Read ElixirScript source** - It's in the git history
4. **Ask the user** - They have context I don't

### What to Avoid

- ❌ Don't create `.md` files (use `.org`)
- ❌ Don't rewrite ElixirScript from scratch
- ❌ Don't try to support old Elixir versions
- ❌ Don't implement features not in the roadmap
- ❌ Don't add OTP support (out of scope)

### What to Do

- ✅ Follow the phased roadmap
- ✅ Keep changes incremental
- ✅ Write tests for new features
- ✅ Update docs when changing behavior
- ✅ Ask before major decisions

---

## 📚 Essential Resources

### ElixirScript (Original)

- **Repo:** https://github.com/elixirscript/elixirscript
- **Docs:** https://hexdocs.pm/elixir_script/
- **Last release:** v0.32.1 (2018-03-17)

### Elixir Language

- **Changelog:** https://github.com/elixir-lang/elixir/blob/main/CHANGELOG.md
- **v1.17 Release:** https://elixir-lang.org/blog/2024/06/12/elixir-v1-17-0-released/
- **v1.18 Release:** https://elixir-lang.org/blog/2024/12/19/elixir-v1-18-0-released/
- **Docs:** https://hexdocs.pm/elixir/

### JavaScript AST

- **ESTree Spec:** https://github.com/estree/estree
- **Elixir ESTree:** https://github.com/elixirscript/elixir-estree

### Pattern Matching

- **Tailored:** https://github.com/elixirscript/tailored (ElixirScript's lib)

---

## 🎯 Current Priority: Phase 0

### Next Immediate Steps

1. **Fork ElixirScript**
   ```bash
   cd packages/curupira_script
   git clone https://github.com/elixirscript/elixirscript.git temp
   cp -r temp/* .
   rm -rf temp
   ```

2. **Update mix.exs**
   - Change app name to `:curupira_script`
   - Bump Elixir to `~> 1.17`
   - Update dependencies

3. **Fix compilation**
   - Run `mix deps.get`
   - Run `mix compile`
   - Fix errors one by one

4. **Run tests**
   - `mix test`
   - Document failures
   - Fix critical ones

5. **Setup CI**
   - Create `.github/workflows/curupira_script.yml`
   - Test on multiple Elixir/OTP versions

---

## 🔍 Debugging Tips

### When compilation fails:

1. Check Elixir version: `elixir --version` (need 1.17+)
2. Check OTP version: `erl -eval '{ok, Version} = file:read_file(filename:join([code:root_dir(), "releases", erlang:system_info(otp_release), "OTP_VERSION"])), io:fwrite(Version), halt().' -noshell` (need 26+)
3. Clean deps: `rm -rf _build deps && mix deps.get`

### When tests fail:

1. Read test output carefully
2. Check if feature requires new Elixir version
3. Check if ElixirScript didn't implement it
4. Document as "known limitation" if needed

### When JavaScript output is wrong:

1. Check `priv/javascript/lib/` for runtime implementation
2. Compare with Elixir behavior in IEx
3. Add test case
4. Fix runtime or compiler

---

## 📊 Success Metrics

### Phase 0 Complete When:

- ✅ ElixirScript code runs on Elixir 1.17+
- ✅ All tests pass (or failures documented)
- ✅ CI pipeline is green
- ✅ Can compile simple Elixir module to JS

### Phase 1 Complete When:

- ✅ Stepped ranges work
- ✅ then/tap work
- ✅ is_non_struct_map guard works
- ✅ Duration type works
- ✅ All with tests

### Phase 2 Complete When:

- ✅ JSON module works
- ✅ 30+ new Enum functions
- ✅ 20+ new String functions
- ✅ Date/Time shifting works

---

## 🗣️ Communication Style

**User Preference:**
- Technical and direct
- Org mode, not Markdown (except .llm/)
- Emacs user
- Prefers doing over talking

**When Responding:**
- Get to the point quickly
- Show code, not explanations
- Ask clarifying questions if needed
- Suggest next steps, don't wait

---

## 🎬 Quick Start for New Session

1. **Read this file** (you are here ✓)
2. **Read [design.org](.llm/design.org)** - Full technical design
3. **Check current phase** in readme.org
4. **Look at last commit** for context
5. **Ask user**: "What should we work on?"

---

**Remember:** We're building this incrementally. Small steps, working code, constant progress.

**Current Phase:** Phase 0 - Architecture Study
**Next Task:** Clone ElixirScript as reference, begin documentation

Good luck! 🚀

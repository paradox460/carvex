# Carvex

<div align=center>

[![Hex.pm](https://img.shields.io/hexpm/v/carvex?style=for-the-badge&color=%23714a94)](https://hex.pm/packages/carvex)

</div>

A [Carve](https://markup-carve.github.io/carve/) markup parser and renderer for Elixir.

Parsing and rendering are powered by the [carve-rs](https://github.com/markup-carve/carve-rs)
engine (crate `carve-lang`) through a Rustler NIF. The API is a port of
[Djot](https://hex.pm/packages/djot), itself heavily "inspired" by [MDEx](https://hex.pm/packages/mdex):
a document AST, a plugin pipeline, syntax highlighting, sanitization, HEEx, and streaming.

## Usage

```elixir
Carvex.to_html("hello *world*!")
# => {:ok, "<p>hello <strong>world</strong>!</p>"}

Carvex.to_html!("# Hi", render: [sections: false])
# => "<h1 id=\"Hi\">Hi</h1>"
```

### Carve options

Options are grouped like MDEx's; see `Carvex.new/1` for the full list.

- `parse:` - `positions` (record `pos` on every node), `lowercase_heading_ids`,
  `ascii_heading_ids` (`:off`, `:fold`, `:strict`).
- `render:` - `sections` (wrap headings in `<section>`, default `true`),
  `source_lines`, `mode` (`:interactive` or `:static`, which flattens interactive
  constructs), `safe`, `profile`, `profile_base_host`, `mention_url`, `tag_url`,
  `symbols`, `smart_typography` (Markdown output), `align_tables` (`to_carve/2`).

`safe: true` escapes raw HTML (`` `x`{=html} ``, ```` ```=html ````) instead of
emitting it. `profile:` applies one of carve-rs's feature-restriction profiles
(`:full`, `:article`, `:comment`, `:minimal`) for untrusted input; over-length input
is an error:

```elixir
Carvex.to_html("`<b>x</b>`{=html}", render: [safe: true])
# => {:ok, "<p>&lt;b&gt;x&lt;/b&gt;</p>"}

Carvex.to_html("# Head\n\ntext", render: [profile: :comment])
# => {:ok, "<p># Head</p>\n<p>text</p>"}

Carvex.to_html(String.duplicate("a", 10_001), render: [profile: :minimal])
# => {:error, %Carvex.CarveError{reason: {:profile_violation, "..."}}}
```

`symbols:` values are emitted as trusted raw HTML; never build them from user input.

### Extensions

carve-rs's built-in extensions are enabled by name, in render order, with options
where the extension takes them:

```elixir
Carvex.to_html!("# Intro\n\n## Usage\n",
  extensions: [:table_of_contents, heading_permalinks: [symbol: "§"]],
  render: [sections: false]
)
# => "<nav class=\"toc\" aria-label=\"Table of contents\">\n<ul>\n<li><a href=\"#Intro\">Intro</a>…"

Carvex.extensions()
# => [:autolink, :citations, :code_callouts, :code_group, …]
```

Options are validated (unknown names and keys raise). Extensions and profiles also
apply when rendering an edited document.

### Document AST

`Carvex.parse_document/2` returns a `%Carvex.Document{}` whose nodes (`Carvex.Heading`,
`Carvex.Paragraph`, `Carvex.Strong`, …) mirror Carve's
[AST exchange format](https://github.com/markup-carve/carve/blob/main/docs/ast-json.md)
and support `Access` and `Enumerable`, Floki-style. Attributes are
`%Carvex.Attributes{}`; child lists are named `nodes`.

```elixir
doc = Carvex.parse_document!("# Hi\n\nSome *bold* text")
doc[Carvex.Strong]
# => [%Carvex.Strong{nodes: [%Carvex.Text{value: "bold"}]}]

doc
|> Carvex.Document.update_nodes(Carvex.Strong, &%Carvex.Emphasis{nodes: &1.nodes})
|> Carvex.to_html!()
# => "<section id=\"Hi\">\n  <h1>Hi</h1>\n  <p>Some <em>bold</em> text</p>\n</section>"
```

### Plugins and pipeline

Plugins expose `attach/2` and use the same functions as MDEx plugins
(`register_options/2`, `put_options/2`, `append_steps/2`, `halt/1`, …).
See `Carvex.Document` for more. Use `Carvex.Raw` nodes with `Carvex.safe_html/2`
to inject HTML from a plugin; `Carvex.Raw` is emitted verbatim regardless of `safe:`
and profiles.

```elixir
Carvex.to_html!("hi", plugins: [{MyPlugin, my_option: true}])
```

Carvex sets two private keys that steps can read with `Carvex.Document.get_private/3`:

- `:heex` is `true` while rendering for `to_heex/2` or `~CRV"..."HEEX`. `Carvex.Raw`
  is written verbatim, so pass `heex: true` to `Carvex.safe_html/2` to turn `{`/`}`
  into entities, or HEEx will read them as expressions.
- `:stream` is `%{id: id}` on each per-block document from `Carvex.stream/2`. Skip
  page-level injections (scripts, styles) there and put the id in element ids
  so they stay unique across blocks.

```elixir
defmodule DiagramPlugin do
  alias Carvex.Document

  def attach(doc, _opts) do
    Document.append_steps(doc, diagrams: &diagrams/1)
  end

  defp diagrams(doc) do
    heex? = Document.get_private(doc, :heex, false)

    prefix =
      case Document.get_private(doc, :stream) do
        %{id: id} -> "diagram-#{id}"
        nil -> "diagram"
      end

    {doc, _} =
      Carvex.traverse_and_update(doc, 1, fn
        %Carvex.CodeBlock{lang: "diagram"} = block, n ->
          body = Carvex.safe_html(block.content, sanitize: nil, escape: true, heex: heex?)
          {%Carvex.Raw{content: ~s(<pre id="#{prefix}-#{n}" class="diagram">#{body}</pre>)}, n + 1}

        node, n ->
          {node, n}
      end)

    doc
  end
end
```

### Syntax highlighting

Carvex supports syntax highlighting via [syntect](https://github.com/syntect/syntect) and
[Lumis](https://hex.pm/packages/lumis). Configure it with `syntax_highlight:`. The
`:syntect` engine is built in; Lumis needs `{:lumis, "~> 0.10"}` plus a parser package
such as `{:lumis_wasm_elixir, "~> 0.26"}` in your deps, and you select it with
`engine: :lumis`.

```elixir
Carvex.to_html!(source, syntax_highlight: [engine: :syntect, opts: [theme: "Dracula"]])
Carvex.to_html!(source, syntax_highlight: [engine: :lumis, opts: [formatter: {:html_inline, theme: "onedark"}]])
```

Code blocks take decorators as Carve block attributes on the line above the fence:

````carve
{theme=Dracula pre_class="a b" highlight_lines="1,3-5" highlight_lines_class=hl}
```elixir
IO.puts("hi")
```
````

| Decorator | Effect |
| --- | --- |
| `theme` | Overrides the configured theme (syntect, Lumis `:html_inline` / `:terminal`) |
| `pre_class` | Extra classes on `<pre>` |
| `highlight_lines` | Lines to highlight: comma-separated `N` or `N-M`; invalid entries are skipped |
| `highlight_lines_style` | Inline style for highlighted lines |
| `highlight_lines_class` | Extra class for highlighted lines |
| `include_highlights` | `true` adds a `data-highlight` attribute with the scope name (Lumis `:html_inline` / `:html_multi_themes` only) |

Decorators never appear in the output. Without `syntax_highlight:`, `pre_class` still
becomes a class on `<pre>` and the rest are ignored. Code blocks whose language an
enabled extension renders (e.g. `mermaid` with `:fenced_render`, `math` with
`:math_block`) are left to that extension.

### Sanitization

```elixir
Carvex.to_html!(source, sanitize: Carvex.Document.default_sanitize_options())
Carvex.safe_html("<script>x</script><b>ok</b>")
# => "<b>ok</b>"
```

Sanitizing runs on the final HTML, including `Carvex.Raw` nodes from plugins. The
defaults keep carve's own footnote, section and task-list markup. Scripts and
attributes outside the allowlist (such as `phx-update`) are removed unless you allow
them, e.g. with `add_tag_attributes:` or `add_generic_attribute_prefixes:`. You can't
combine `sanitize:` with HEEx rendering; `to_heex/2` returns a `Carvex.CarveError`
with reason `:sanitize_unsupported_in_heex`.

### HEEx

With `{:phoenix_live_view, "~> 1.2"}`, Carve can contain components and expressions:

```elixir
use Carvex
import Phoenix.Component

def render(assigns) do
  ~CRV"""
  Hello {@name}

  <.link href="/x">go</.link>
  """HEEX
end

Carvex.to_heex!("Hi {@name}", assigns: %{name: "Ann"})
```

Carve's own brace syntax (`{.class}`, `[Tab]{kbd}`, `{^sup^}`, `{,sub,}`, `{:fr}`,
`{~old~>new~}`, …) is left alone. A bare `{name}` alone on a line is a Carve block
attribute line, so write `{@name}` or put the expression inline. Braces in the
rendered HTML become entities, except inside `<script>` and `<style>`.

`to_heex/2` and `to_heex!/2` are macros, available after `use Carvex` or
`require Carvex`. They compile the template at runtime in the caller's environment,
so imports such as `Phoenix.Component` apply. The compiler can't see that, though,
and warns that an import only the template uses is unused. `~CRV"..."HEEX` compiles
the template at compile time and doesn't trigger the warning.

### Sigil

`use Carvex` (or `import Carvex.Sigil`) provides `~CRV`, evaluated at compile time:
`~CRV"..."` returns a `%Carvex.Document{}`, `~CRV"..."HTML` the HTML string, and
`~CRV"..."HEEX` compiles a HEEx template whose code needs an `assigns` variable in
scope where the sigil is used (as in `render(assigns)` above). Options given to
`use Carvex, opts` apply to every `~CRV` in the module.

```elixir
use Carvex

~CRV"""
Some text \
compiled to HTML at compile time!
"""HTML
# => "<p>Some text <br>\ncompiled to HTML at compile time!</p>"
```

### Other outputs

```elixir
Carvex.to_markdown!("/hi/ *there* =mark=")
# => "*hi* **there** <mark>mark</mark>\n"

Carvex.to_plain_text!("# Title\n\n/hi/ *there*")
# => "Title\n\nhi there\n"

Carvex.to_ansi!("*bold*")

Carvex.to_carve!("#  Title\n\n- a\n-  b")
# => "# Title\n\n- a\n- b\n"
```

`to_carve/2` is carve-rs's canonical writer (formatter); given a document it writes
the (possibly edited) tree back to Carve source. All outputs accept documents and the
same options as `to_html/2`.

### Linting

```elixir
Carvex.lint("{#orphan}\n")
# => [%Carvex.LintWarning{line: 1, column: 1, rule: "unattached-block-attribute",
#      message: "This block attribute reaches no block: …", start_offset: 0, end_offset: 9}]
```

`start_offset`/`end_offset` are UTF-8 byte offsets, so
`binary_part(source, w.start_offset, w.end_offset - w.start_offset)` is the flagged text.

### Streaming

```elixir
chunks
|> Carvex.stream()
|> Enum.each(fn {id, doc} -> send(self(), {:block, id, Carvex.to_html!(doc)}) end)
```

Each emission replaces the block with the same `id`. Each block renders standalone,
so a footnote reference resolves only when its definition is in the same block.
Plugins attach once and their steps run on every emitted block document (see the
`:stream` private key above).

### Not exposed

carve-rs features this package does not bind: static-mode build renderers (mermaid
and math callbacks), mention/tag resolver callbacks, `{{ include }}` expansion, and
the importers (Markdown, HTML, Djot, BBCode to Carve).

## Installation

```elixir
def deps do
  [
    {:carvex, "~> 0.0.1"}
  ]
end
```

## See also

This package ports [djot](https://hex.pm/packages/djot) to the Carve language, and is
inspired by the excellent [mdex](https://hex.pm/packages/mdex) package.

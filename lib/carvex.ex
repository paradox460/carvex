defmodule Carvex do
  @moduledoc """
  [Carve](https://markup-carve.github.io/carve/) parsing and rendering, backed by
  the Rust [carve-rs](https://github.com/markup-carve/carve-rs) engine.

  The API follows [MDEx](https://github.com/leandrocp/mdex):

    * `to_html/2` renders source or a `Carvex.Document`; `to_markdown/2`,
      `to_plain_text/2`, `to_ansi/2` and `to_carve/2` render other outputs
    * `parse_document/2` returns a `Carvex.Document` tree you can query and edit
    * plugins and pipeline steps (`Carvex.Document`)
    * carve-rs extensions, profiles and safe mode (`new/1` options)
    * syntax highlighting with syntect or Lumis, with code block decorators
    * HTML sanitization (ammonia)
    * HEEx components and expressions (`to_heex/2`, `~CRV"..."HEEX`)
    * streaming of chunked input (`stream/2`)
    * linting (`lint/2`)

  ## Examples

      iex> Carvex.to_html("Hello *world*!")
      {:ok, "<p>Hello <strong>world</strong>!</p>"}

      iex> Carvex.to_html!("# Hi", render: [sections: false])
      "<h1 id=\\"Hi\\">Hi</h1>"

  ## Code block decorators

  Block attributes on a code block control highlighting and are never rendered:

      {theme=github_dark pre_class="a b" highlight_lines="1,3-5" highlight_lines_style="background: #ff0" highlight_lines_class=hl include_highlights=true}
      ```elixir
      IO.puts("hi")
      ```

  Without `syntax_highlight:`, `pre_class` becomes a class on the code block and
  the other decorators are ignored.

  ## `use Carvex`

  `use Carvex` requires `Carvex`, imports `Carvex.Sigil`, and stores its options in
  `@carvex_options`, which `~CRV` uses at compile time.
  """

  alias Carvex.Document

  @typedoc "Carve source or a document."
  @type source :: String.t() | Document.t()

  @doc """
  Builds a document from options. `:source` is parsed when the pipeline runs.

  ## Options

  #{NimbleOptions.docs(Carvex.Document.options_schema())}
  """
  @spec new(keyword()) :: Document.t()
  def new(opts \\ []) do
    {source, rest} = Keyword.pop(opts, :source)

    %Document{}
    |> Document.put_options(rest)
    |> Document.put_source(source)
  end

  @doc """
  Parses source into a `Carvex.Document` and runs the pipeline.

      iex> {:ok, doc} = Carvex.parse_document("Hello *world*")
      iex> doc.nodes
      [%Carvex.Paragraph{nodes: [%Carvex.Text{value: "Hello "}, %Carvex.Strong{nodes: [%Carvex.Text{value: "world"}]}]}]
  """
  @spec parse_document(String.t(), keyword()) :: {:ok, Document.t()} | {:error, Exception.t()}
  def parse_document(source, opts \\ []) when is_binary(source) do
    case Document.run(new([source: source] ++ opts)) do
      {_doc, exception} -> {:error, exception}
      doc -> {:ok, doc}
    end
  end

  @doc "Like `parse_document/2` but raises on error."
  @spec parse_document!(String.t(), keyword()) :: Document.t()
  def parse_document!(source, opts \\ []) do
    case parse_document(source, opts) do
      {:ok, doc} -> doc
      {:error, exception} -> raise exception
    end
  end

  @doc """
  Renders source or a document to HTML. `opts` are merged into the document
  options (see `new/1`).

      iex> Carvex.to_html("/hi/")
      {:ok, "<p><em>hi</em></p>"}
  """
  @spec to_html(source(), keyword()) :: {:ok, String.t()} | {:error, Exception.t()}
  def to_html(source_or_doc, opts \\ []), do: render(source_or_doc, opts, :html)

  @doc "Like `to_html/2` but raises on error."
  @spec to_html!(source(), keyword()) :: String.t()
  def to_html!(source_or_doc, opts \\ []), do: to_html(source_or_doc, opts) |> unwrap!()

  @doc """
  Renders source or a document to Markdown.

      iex> Carvex.to_markdown("/hi/ *there*")
      {:ok, "*hi* **there**\\n"}
  """
  @spec to_markdown(source(), keyword()) :: {:ok, String.t()} | {:error, Exception.t()}
  def to_markdown(source_or_doc, opts \\ []), do: render(source_or_doc, opts, :markdown)

  @doc "Like `to_markdown/2` but raises on error."
  @spec to_markdown!(source(), keyword()) :: String.t()
  def to_markdown!(source_or_doc, opts \\ []), do: to_markdown(source_or_doc, opts) |> unwrap!()

  @doc """
  Renders source or a document to plain text.

      iex> Carvex.to_plain_text("/hi/ *there*")
      {:ok, "hi there\\n"}
  """
  @spec to_plain_text(source(), keyword()) :: {:ok, String.t()} | {:error, Exception.t()}
  def to_plain_text(source_or_doc, opts \\ []), do: render(source_or_doc, opts, :plain_text)

  @doc "Like `to_plain_text/2` but raises on error."
  @spec to_plain_text!(source(), keyword()) :: String.t()
  def to_plain_text!(source_or_doc, opts \\ []),
    do: to_plain_text(source_or_doc, opts) |> unwrap!()

  @doc "Renders source or a document to ANSI-styled terminal text."
  @spec to_ansi(source(), keyword()) :: {:ok, String.t()} | {:error, Exception.t()}
  def to_ansi(source_or_doc, opts \\ []), do: render(source_or_doc, opts, :ansi)

  @doc "Like `to_ansi/2` but raises on error."
  @spec to_ansi!(source(), keyword()) :: String.t()
  def to_ansi!(source_or_doc, opts \\ []), do: to_ansi(source_or_doc, opts) |> unwrap!()

  @doc """
  Writes canonical Carve source: carve-rs's formatter for source, and on a
  document the (possibly edited) tree written back to Carve.

      iex> Carvex.to_carve("#  Title")
      {:ok, "# Title\\n"}
  """
  @spec to_carve(source(), keyword()) :: {:ok, String.t()} | {:error, Exception.t()}
  def to_carve(source_or_doc, opts \\ []), do: render(source_or_doc, opts, :carve)

  @doc "Like `to_carve/2` but raises on error."
  @spec to_carve!(source(), keyword()) :: String.t()
  def to_carve!(source_or_doc, opts \\ []), do: to_carve(source_or_doc, opts) |> unwrap!()

  defp render(source_or_doc, opts, target),
    do: source_or_doc |> document(opts) |> Carvex.Renderer.render(target, false)

  defp unwrap!({:ok, out}), do: out
  defp unwrap!({:error, exception}), do: raise(exception)

  @doc false
  def document(source, opts) when is_binary(source), do: new([source: source] ++ opts)
  def document(%Document{} = doc, opts), do: Document.put_options(doc, opts)

  @lint_schema [
    extensions: [type: {:list, :any}, default: [], doc: "As in `new/1`."],
    parse: [type: :keyword_list, default: [], doc: "As in `new/1`."],
    caption_hints: [
      type: :boolean,
      default: false,
      doc: "Also flag paragraphs that look like a caption missing its `^` marker."
    ]
  ]

  @doc """
  Lints Carve source, returning carve-rs's diagnostics in source order.

  Offsets in each `Carvex.LintWarning` are UTF-8 byte offsets into `source`.

      iex> [warning] = Carvex.lint("{#orphan}\\n")
      iex> warning.rule
      "unattached-block-attribute"

  ## Options

  #{NimbleOptions.docs(@lint_schema)}
  """
  @spec lint(String.t(), keyword()) :: [Carvex.LintWarning.t()]
  def lint(source, opts \\ []) when is_binary(source) do
    opts = NimbleOptions.validate!(opts, @lint_schema)
    doc = new(extensions: opts[:extensions], parse: opts[:parse])
    native = %{Carvex.Renderer.native_options(doc) | lint_caption_hints: opts[:caption_hints]}

    case Carvex.Native.lint(source, native) do
      {:ok, warnings} -> warnings
      {:error, reason} -> raise Carvex.CarveError.native(reason)
    end
  end

  @doc """
  The carve-rs extension names accepted by the `:extensions` option.

      iex> :table_of_contents in Carvex.extensions()
      true
  """
  @spec extensions() :: [atom()]
  def extensions do
    # Registry keys are trusted and bounded.
    Carvex.Native.extensions() |> Enum.map(&String.to_atom(String.replace(&1, "-", "_")))
  end

  @doc """
  Sanitizes and/or escapes an HTML string. Plugins use this to build safe
  `Carvex.Raw` nodes.

  ## Options

    * `:sanitize` - ammonia options merged over `Carvex.Document.default_sanitize_options/0`,
      or `nil` to skip sanitizing. Defaults to the default sanitize options.
    * `:escape` - HTML-escape `& < > " '` after sanitizing. Defaults to `false`.
    * `:heex` - replace `{` and `}` with `&lbrace;` / `&rbrace;` last, so the
      HTML is not read as HEEx expressions by `to_heex/2`. Pass
      `Carvex.Document.get_private(doc, :heex, false)` from a step. Defaults to `false`.

  ## Examples

      iex> Carvex.safe_html("<script>x</script><b onclick=\\"y\\">hi</b>")
      "<b>hi</b>"

      iex> Carvex.safe_html("<a>&</a>", sanitize: nil, escape: true)
      "&lt;a&gt;&amp;&lt;/a&gt;"

      iex> Carvex.safe_html("<pre>A{b}</pre>", sanitize: nil, heex: true)
      "<pre>A&lbrace;b&rbrace;</pre>"
  """
  @spec safe_html(String.t(), keyword()) :: String.t()
  def safe_html(html, opts \\ []) when is_binary(html) do
    opts =
      NimbleOptions.validate!(opts,
        sanitize: [type: {:or, [nil, :keyword_list]}, default: []],
        escape: [type: :boolean, default: false],
        heex: [type: :boolean, default: false]
      )

    sanitize =
      case opts[:sanitize] do
        nil ->
          nil

        kw ->
          Document.default_sanitize_options()
          |> Keyword.merge(kw)
          |> NimbleOptions.validate!(Document.sanitize_options_schema())
          |> Map.new()
      end

    case Carvex.Native.safe_html(html, sanitize, opts[:escape]) do
      {:ok, html} ->
        if opts[:heex], do: Carvex.HEEx.escape_braces(html), else: html

      {:error, reason} ->
        raise Carvex.CarveError, reason: reason, message: "safe_html failed: #{reason}"
    end
  end

  @doc """
  Streams chunks of Carve source, emitting `{id, %Carvex.Document{}}` for each
  top-level block that is new or changed. A later emission with the same id
  replaces the earlier one; an empty document means the block was removed.

  Each block renders standalone: a footnote reference resolves only if its
  definition is in the same block. `opts` are as in `new/1` (plugins attach
  once); `:source` is not accepted.

      iex> ["# Hel", "lo\\n\\nPara"]
      ...> |> Carvex.stream()
      ...> |> Enum.map(fn {id, doc} -> {id, Carvex.to_html!(doc, render: [sections: false])} end)
      [{0, "<h1 id=\\"Hel\\">Hel</h1>"}, {0, "<h1 id=\\"Hello\\">Hello</h1>"}, {1, "<p>Para</p>"}]
  """
  @spec stream(Enumerable.t(), keyword()) :: Enumerable.t()
  defdelegate stream(enumerable, opts \\ []), to: Carvex.Stream

  @doc "Traverses and updates the tree post-order; returning `nil` or `:pop` removes a node."
  defdelegate traverse_and_update(doc, fun), to: Carvex.Document.Traversal

  @doc "Like `traverse_and_update/2` with an accumulator; the function returns `{node, acc}`."
  defdelegate traverse_and_update(doc, acc, fun), to: Carvex.Document.Traversal

  @doc false
  defmacro __using__(opts) do
    quote do
      require Carvex
      import Carvex.Sigil
      @carvex_options unquote(opts)
    end
  end

  @doc """
  Renders Carve with HEEx components and expressions into a `Phoenix.LiveView.Rendered`.

  Requires `{:phoenix_live_view, "~> 1.2"}`. HEEx tags (`<.link>`, `<Mod.fun>`,
  `<:slot>`), `{@expr}` expressions and `<%= %>` blocks are recognized outside
  code; Carve brace syntax like `{.class}`, `[Tab]{kbd}`, `{^sup^}` or a block
  attribute line (`{loose}`) is left alone, so write `{@name}` rather than a bare
  `{name}` alone on a line. Explicit `` `...`{=heex} `` and ```` ```=heex ```` raw
  blocks also work.

  Braces in the rendered HTML (text, code, attributes, raw `html`) become
  `&lbrace;`/`&rbrace;`, except inside `<script>` and `<style>`.

  Assigns come from the `:assigns` option. The template is compiled at runtime
  with the caller's environment, so imports (e.g. `Phoenix.Component`) apply.
  `sanitize:` is not supported.
  """
  defmacro to_heex(source, opts \\ []) do
    ensure_live_view!()

    quote do
      Carvex.HEEx.__to_heex__(unquote(source), unquote(opts), unquote(Macro.escape(__CALLER__)))
    end
  end

  @doc "Like `to_heex/2` but raises on error."
  defmacro to_heex!(source, opts \\ []) do
    ensure_live_view!()

    quote do
      Carvex.HEEx.__to_heex__!(unquote(source), unquote(opts), unquote(Macro.escape(__CALLER__)))
    end
  end

  defp ensure_live_view! do
    unless Carvex.HEEx.live_view_available?() do
      raise ArgumentError, ~s(Carvex.to_heex/2 requires {:phoenix_live_view, "~> 1.2"})
    end
  end
end

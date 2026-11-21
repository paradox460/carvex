defmodule Carvex.Renderer do
  @moduledoc false

  alias Carvex.{AST, CarveError, Document, Native}

  @type target :: :html | :markdown | :plain_text | :ansi | :carve

  @spec render(Document.t(), target(), boolean()) :: {:ok, String.t()} | {:error, Exception.t()}
  def render(%Document{} = doc, target, heex?) do
    if fast_path?(doc, target, heex?) do
      with {:ok, out} <- native(Native.render_source(doc.source, target, native_options(doc))) do
        post_process(out, doc, target, heex?, %{})
      end
    else
      with %Document{} = doc <- run(Document.put_private(doc, :heex, heex?)),
           {:ok, doc} <- highlight(doc, target, heex?),
           {:ok, json, raws} <- AST.encode(doc.nodes, target, heex?),
           {:ok, out} <- native(Native.render_json(json, target, native_options(doc))) do
        post_process(out, doc, target, heex?, raws)
      end
    end
  end

  # Any Elixir-side transform of the tree must also disable this path.
  defp fast_path?(doc, target, heex?) do
    doc.nodes == [] and is_binary(doc.source) and doc.current_steps == [] and not heex? and
      (target != :html or
         (Document.get_option(doc, :syntax_highlight) == nil and
            not Carvex.SyntaxHighlight.decorated?(doc.source)))
  end

  defp run(doc) do
    case Document.run(doc) do
      {_doc, exception} -> {:error, exception}
      doc -> doc
    end
  end

  defp highlight(doc, :html, heex?), do: Carvex.SyntaxHighlight.apply(doc, heex?)
  defp highlight(doc, _target, _heex?), do: {:ok, doc}

  defp post_process(html, doc, :html, heex?, raws) do
    html = if heex?, do: Carvex.HEEx.escape_html_braces(html), else: html
    sanitize(AST.restore(html, raws), Document.get_option(doc, :sanitize))
  end

  defp post_process(out, _doc, _target, _heex?, _raws), do: {:ok, out}

  defp sanitize(html, nil), do: {:ok, html}

  defp sanitize(html, kw) do
    options = Map.new(NimbleOptions.validate!(kw, Document.sanitize_options_schema()))

    case Native.safe_html(html, options, false) do
      {:ok, html} ->
        {:ok, html}

      {:error, reason} ->
        {:error, %CarveError{reason: reason, message: "sanitize failed: #{reason}"}}
    end
  end

  defp native({:ok, out}), do: {:ok, out}
  defp native({:error, reason}), do: {:error, CarveError.native(reason)}

  @doc false
  # Exactly the NIF's CarveOptionsEx keys.
  @spec native_options(Document.t()) :: map()
  def native_options(doc) do
    parse = Document.get_option(doc, :parse)
    render = Document.get_option(doc, :render)

    %{
      extensions: Carvex.Extensions.to_native(Document.get_option(doc, :extensions, [])),
      positions: Keyword.fetch!(parse, :positions),
      lowercase_heading_ids: Keyword.fetch!(parse, :lowercase_heading_ids),
      ascii_heading_ids: Keyword.fetch!(parse, :ascii_heading_ids),
      sections: Keyword.fetch!(render, :sections),
      source_lines: Keyword.fetch!(render, :source_lines),
      mode: Keyword.fetch!(render, :mode),
      safe: Keyword.fetch!(render, :safe),
      profile: Keyword.fetch!(render, :profile),
      profile_base_host: Keyword.fetch!(render, :profile_base_host),
      mention_url: Keyword.fetch!(render, :mention_url),
      tag_url: Keyword.fetch!(render, :tag_url),
      symbols: Map.to_list(Keyword.fetch!(render, :symbols)),
      smart_typography: Keyword.fetch!(render, :smart_typography),
      align_tables: Keyword.fetch!(render, :align_tables),
      lint_caption_hints: false
    }
  end
end

defmodule Carvex.Sigil do
  @moduledoc """
  The `~CRV` sigil, evaluated at compile time.

    * `~CRV"..."` - a `%Carvex.Document{}` with the parsed nodes
    * `~CRV"..."HTML` - the rendered HTML string
    * `~CRV"..."HEEX` - a `Phoenix.LiveView.Rendered`; requires `assigns` in scope
      and `{:phoenix_live_view, "~> 1.2"}`

  Options come from `use Carvex, opts`.

      iex> import Carvex.Sigil
      iex> ~CRV"*a*"HTML
      "<p><strong>a</strong></p>"
  """

  @doc "Carve sigil; see the module docs."
  defmacro sigil_CRV({:<<>>, _meta, [source]}, modifiers) when is_binary(source) do
    opts = (__CALLER__.module && Module.get_attribute(__CALLER__.module, :carvex_options)) || []

    case modifiers do
      [] ->
        doc = Carvex.parse_document!(source, opts)
        Macro.escape(%Carvex.Document{nodes: doc.nodes})

      ~c"HTML" ->
        Carvex.to_html!(source, opts)

      ~c"HEEX" ->
        html =
          case Carvex.HEEx.render_template(source, opts) do
            {:ok, html} -> html
            {:error, exception} -> raise exception
          end

        Carvex.HEEx.compile(html, %{__CALLER__ | line: __CALLER__.line + 1})

      other ->
        raise ArgumentError, "unsupported ~CRV modifier: #{other}"
    end
  end
end

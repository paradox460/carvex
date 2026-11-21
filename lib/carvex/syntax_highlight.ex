defmodule Carvex.SyntaxHighlight do
  @moduledoc false
  # Strips code block decorators and replaces highlighted code blocks with
  # `Carvex.Raw` nodes before rendering. Ported from Djot.Highlight.

  @compile {:no_warn_undefined, [Lumis]}

  alias Carvex.{Attributes, CarveError, Document}

  @decorators ~w(theme pre_class highlight_lines highlight_lines_style highlight_lines_class include_highlights)

  @syntect_schema [
    theme: [type: {:or, [:string, nil]}, default: nil],
    pre_class: [type: {:or, [:string, nil]}, default: nil]
  ]

  @lumis_schema [formatter: [type: :any, default: {:html_inline, theme: "onedark"}]]

  @html_formatters [:html_inline, :html_linked, :html_multi_themes]

  @doc false
  # Cheap over-approximation that sends decorated sources down the tree path.
  @spec decorated?(String.t()) :: boolean()
  def decorated?(source), do: String.contains?(source, @decorators)

  @spec apply(Document.t(), boolean()) :: {:ok, Document.t()} | {:error, CarveError.t()}
  def apply(%Document{} = doc, heex?) do
    case Document.get_option(doc, :syntax_highlight) do
      nil -> {:ok, Carvex.traverse_and_update(doc, &strip/1)}
      config -> highlight(doc, config, heex?)
    end
  end

  # Decorators are never rendered; `pre_class` becomes classes on the block.
  defp strip(%Carvex.CodeBlock{attrs: %Attributes{} = attrs} = block) do
    attrs =
      Enum.reduce(@decorators, attrs, fn key, attrs ->
        case Attributes.get(attrs, key) do
          nil -> attrs
          _ -> Attributes.delete(attrs, key)
        end
      end)

    classes =
      case block.attrs.key_values do
        %{"pre_class" => pre_class} -> String.split(pre_class)
        _ -> []
      end

    %{block | attrs: Enum.reduce(classes, attrs, &Attributes.add_class(&2, &1))}
  end

  defp strip(node), do: node

  defp highlight(doc, config, heex?) do
    claimed = Carvex.Extensions.claimed_languages(Document.get_option(doc, :extensions, []))

    with {:ok, highlighter} <- highlighter(config[:engine], config[:opts]) do
      {doc, error} =
        Carvex.traverse_and_update(doc, nil, fn
          %Carvex.CodeBlock{lang: lang} = block, nil when lang not in [nil, ""] ->
            if lang in claimed do
              {strip(block), nil}
            else
              case highlighter.(block) do
                {:ok, html} -> {%Carvex.Raw{content: escape_braces(html, heex?)}, nil}
                {:error, reason} -> {strip(block), reason}
              end
            end

          node, acc ->
            {strip(node), acc}
        end)

      case error do
        nil -> {:ok, doc}
        reason -> {:error, error(reason)}
      end
    end
  end

  defp error(:lumis_not_available) do
    %CarveError{
      reason: {:highlight, :lumis_not_available},
      message:
        ~s(syntax_highlight engine :lumis requires {:lumis, "~> 0.10"} and lumis_wasm_* parser packages in your deps)
    }
  end

  defp error(reason) do
    %CarveError{
      reason: {:highlight, reason},
      message: "syntax highlighting failed: #{inspect(reason)}"
    }
  end

  defp escape_braces(html, false), do: html
  defp escape_braces(html, true), do: Carvex.HEEx.escape_braces(html)

  # -- syntect ---------------------------------------------------------------

  defp highlighter(:syntect, opts) do
    opts = NimbleOptions.validate!(opts, @syntect_schema)

    {:ok,
     fn %Carvex.CodeBlock{lang: lang, content: content, header: header, attrs: attrs} ->
       get = &Attributes.get(attrs, &1)

       options = %{
         theme: get.("theme") || opts[:theme],
         pre_class: join_classes([opts[:pre_class], get.("pre_class"), get.("class")]),
         pre_attrs: pre_attrs(attrs, header),
         highlight_lines: parse_lines(get.("highlight_lines")),
         highlight_lines_style: get.("highlight_lines_style"),
         highlight_lines_class: get.("highlight_lines_class")
       }

       Carvex.Native.syntect_highlight(content, lang, options)
     end}
  end

  # -- lumis -----------------------------------------------------------------

  defp highlighter(:lumis, opts) do
    if Code.ensure_loaded?(Lumis) do
      opts = NimbleOptions.validate!(opts, @lumis_schema)

      {name, base} =
        case opts[:formatter] do
          name when is_atom(name) -> {name, []}
          {name, fopts} when is_atom(name) and is_list(fopts) -> {name, fopts}
        end

      {:ok,
       fn %Carvex.CodeBlock{lang: lang, content: content, attrs: attrs} ->
         fopts = lumis_options(name, Keyword.put(base, :language, lang), attrs)

         case Lumis.highlight(content, formatter: {name, fopts}) do
           {:ok, html} -> {:ok, html}
           {:error, error} -> {:error, error}
         end
       end}
    else
      {:error, error(:lumis_not_available)}
    end
  end

  defp pre_attrs(attrs, header) do
    id = Attributes.get(attrs, "id")
    key_values = if attrs, do: attrs.key_values, else: %{}

    Enum.concat([
      if(id, do: [{"id", id}], else: []),
      if(header, do: [{"title", header}], else: []),
      for({k, v} <- key_values, k not in @decorators, do: {k, v})
    ])
  end

  defp lumis_options(name, fopts, attrs) do
    html? = name in @html_formatters
    get = &Attributes.get(attrs, &1)

    fopts
    |> put_if(html?, :pre_class, fn ->
      join_classes([fopts[:pre_class], get.("pre_class"), get.("class")])
    end)
    |> put_if(html?, :pre_attrs, fn ->
      case get.("id") do
        nil -> fopts[:pre_attrs]
        id -> Keyword.put(fopts[:pre_attrs] || [], :id, id)
      end
    end)
    |> put_if(name in [:html_inline, :terminal], :theme, fn ->
      get.("theme") || fopts[:theme]
    end)
    |> put_if(
      name in [:html_inline, :html_multi_themes] and get.("include_highlights") == "true",
      :include_highlights,
      fn -> true end
    )
    |> put_if(true, :highlight_lines, fn -> lumis_lines(name, attrs, fopts[:highlight_lines]) end)
  end

  defp lumis_lines(name, attrs, default) do
    case attrs |> Attributes.get("highlight_lines") |> parse_lines() do
      [] ->
        default

      ranges ->
        lines =
          Enum.map(ranges, fn
            {n, n} -> n
            {n, m} -> n..m
          end)

        style = Attributes.get(attrs, "highlight_lines_style")
        class = Attributes.get(attrs, "highlight_lines_class")

        extra =
          case name do
            n when n in [:html_inline, :html_multi_themes] -> [style: style, class: class]
            :html_linked -> [class: class]
            _ -> []
          end

        extra
        |> Enum.reject(fn {_, v} -> is_nil(v) end)
        |> Map.new()
        |> Map.put(:lines, lines)
    end
  end

  # Puts `key` only when `cond?` and the computed value is non-nil.
  defp put_if(opts, false, _key, _fun), do: opts

  defp put_if(opts, true, key, fun) do
    case fun.() do
      nil -> opts
      value -> Keyword.put(opts, key, value)
    end
  end

  defp join_classes(parts) do
    case parts |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ") do
      "" -> nil
      classes -> classes
    end
  end

  @doc false
  # "1,3-5" -> [{1, 1}, {3, 5}]; invalid tokens are skipped.
  def parse_lines(nil), do: []

  def parse_lines(spec) do
    spec
    |> String.split(",")
    |> Enum.flat_map(fn token ->
      case token |> String.trim() |> String.split("-") |> Enum.map(&String.trim/1) do
        [n] -> range(n, n)
        [n, m] -> range(n, m)
        _ -> []
      end
    end)
  end

  defp range(a, b) do
    with {n, ""} <- Integer.parse(a),
         {m, ""} <- Integer.parse(b),
         true <- n >= 1 and n <= m do
      [{n, m}]
    else
      _ -> []
    end
  end
end

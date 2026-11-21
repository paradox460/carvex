defmodule Carvex.AST do
  @moduledoc false
  # Codec between carve's AST exchange JSON (resources/ast-schema.json) and the
  # node structs in lib/carvex/nodes.ex. Elixir recursion is heap-backed, so
  # trees nested to carve's container cap are safe here.

  alias Carvex.{Attributes, CarveError, Nodes, Pos}

  @const_true %{
    Carvex.BlockQuote => [:fenced],
    Carvex.DefinitionList => [:loose],
    Carvex.List => [:bare_marker],
    Carvex.Paragraph => [:block_image],
    Carvex.Strong => [:bold_italic],
    Carvex.Image => [:resolved],
    Carvex.Link => [:resolved]
  }

  @pos_keys %{
    "startLine" => :start_line,
    "endLine" => :end_line,
    "startColumn" => :start_column,
    "endColumn" => :end_column,
    "startOffset" => :start_offset,
    "endOffset" => :end_offset,
    "file" => :file
  }
  @pos_fields Map.new(@pos_keys, fn {k, v} -> {v, k} end)

  @token_prefix "carvexraw"

  ## Decoding

  @spec decode(binary()) :: {:ok, [struct()]} | {:error, CarveError.t()}
  def decode(json) when is_binary(json) do
    case JSON.decode(json) do
      {:ok, %{"type" => "document"} = root} ->
        {:ok, decode_list(Map.get(root, "children", []))}

      {:ok, other} ->
        error({:invalid_ast_root, other})

      {:error, reason} ->
        error({:invalid_json, reason})
    end
  catch
    {:carvex_ast, reason} -> error(reason)
  end

  defp decode_list(list) when is_list(list), do: Enum.map(list, &decode_node/1)
  defp decode_list(other), do: throw({:carvex_ast, {:invalid_ast_value, other}})

  defp decode_node(%{"type" => type} = map) do
    module = Nodes.module_for(type) || throw({:carvex_ast, {:unknown_ast_type, type}})
    fields = Nodes.spec(module).fields

    Enum.reduce(map, struct(module), fn
      {"type", _}, node ->
        node

      {key, value}, node ->
        case Elixir.List.keyfind(fields, key, 1) do
          {field, _, kind} -> Map.put(node, field, decode_value(kind, value))
          nil -> throw({:carvex_ast, {:unknown_ast_field, type, key}})
        end
    end)
  end

  defp decode_node(other), do: throw({:carvex_ast, {:invalid_ast_value, other}})

  defp decode_value(_kind, nil), do: nil
  defp decode_value(kind, list) when kind in [:blocks, :inlines], do: decode_list(list)
  defp decode_value(:block, map), do: decode_node(map)

  defp decode_value(:attrs, m) do
    %Attributes{
      id: m["id"],
      classes: m["classes"] || [],
      key_values: m["keyValues"] || %{},
      order: m["order"] || []
    }
  end

  defp decode_value(:pos, m) do
    Enum.reduce(m, %Pos{}, fn {k, v}, pos ->
      case @pos_keys do
        %{^k => field} -> Map.put(pos, field, v)
        _ -> throw({:carvex_ast, {:unknown_ast_field, "pos", k}})
      end
    end)
  end

  defp decode_value(:pairs, pairs) do
    Enum.map(pairs, fn pair ->
      %Carvex.RubyPair{
        base: decode_list(Map.get(pair, "base", [])),
        annotation: decode_list(Map.get(pair, "annotation", []))
      }
    end)
  end

  defp decode_value(_kind, value), do: value

  ## Encoding

  @spec encode([struct()], atom(), boolean()) ::
          {:ok, binary(), %{String.t() => String.t()}} | {:error, CarveError.t()}
  def encode(nodes, target, heex?) do
    state = %{
      html?: target == :html,
      heex?: heex? and target == :html,
      nonce: Base.encode16(:crypto.strong_rand_bytes(8), case: :lower),
      next: 0,
      raws: %{}
    }

    {children, state} = encode_list(nodes, :blocks, state)
    root = %{"type" => "document", "children" => children, "srcByteLength" => 0}
    {:ok, JSON.encode!(root), state.raws}
  catch
    {:carvex_ast, reason} -> error(reason)
  end

  defp encode_list(nodes, kind, state) when is_list(nodes),
    do: Enum.map_reduce(nodes, state, &encode_node(&1, kind, &2))

  defp encode_list(other, _kind, _state), do: throw({:carvex_ast, {:invalid_node, other}})

  defp encode_node(%Carvex.Raw{content: html}, kind, %{html?: true} = state),
    do: placeholder(html, kind, state)

  defp encode_node(%Carvex.Raw{content: html}, kind, state) do
    type = if kind == :inlines, do: "raw_inline", else: "raw_block"
    {%{"type" => type, "format" => "html", "content" => html}, state}
  end

  defp encode_node(%mod{format: "heex", content: content}, kind, %{heex?: true} = state)
       when mod in [Carvex.RawInline, Carvex.RawBlock],
       do: placeholder(content, kind, state)

  defp encode_node(%module{} = node, _kind, state) do
    case Nodes.spec(module) do
      %{type: type, fields: fields} -> encode_fields(node, type, fields, state)
      nil -> throw({:carvex_ast, {:invalid_node, node}})
    end
  end

  defp encode_node(other, _kind, _state), do: throw({:carvex_ast, {:invalid_node, other}})

  defp encode_fields(%module{} = node, type, fields, state) do
    omit_false = Map.get(@const_true, module, [])

    Enum.reduce(fields, {%{"type" => type}, state}, fn {field, key, kind}, {map, state} ->
      case Map.fetch!(node, field) do
        nil ->
          {map, state}

        false when kind == :scalar ->
          if field in omit_false, do: {map, state}, else: {Map.put(map, key, false), state}

        value ->
          case encode_value(kind, value, state) do
            {:skip, state} -> {map, state}
            {encoded, state} -> {Map.put(map, key, encoded), state}
          end
      end
    end)
  end

  defp encode_value(kind, list, state) when kind in [:blocks, :inlines],
    do: encode_list(list, kind, state)

  defp encode_value(:block, %_{} = node, state), do: encode_node(node, :block, state)
  defp encode_value(:block, other, _state), do: throw({:carvex_ast, {:invalid_node, other}})

  defp encode_value(:attrs, %Attributes{} = attrs, state) do
    if Attributes.empty?(attrs) do
      {:skip, state}
    else
      map =
        [
          {"id", attrs.id, nil},
          {"classes", attrs.classes, []},
          {"keyValues", attrs.key_values, %{}},
          {"order", attrs.order, []}
        ]
        |> Enum.reject(fn {_, value, empty} -> value == empty end)
        |> Map.new(fn {key, value, _} -> {key, value} end)

      {map, state}
    end
  end

  defp encode_value(:pos, %Pos{} = pos, state) do
    map =
      for {field, key} <- @pos_fields,
          value = Map.fetch!(pos, field),
          value != nil,
          into: %{},
          do: {key, value}

    {map, state}
  end

  defp encode_value(:pairs, pairs, state) do
    Enum.map_reduce(pairs, state, fn %Carvex.RubyPair{base: base, annotation: annotation},
                                     state ->
      {base, state} = encode_list(base, :inlines, state)
      {annotation, state} = encode_list(annotation, :inlines, state)
      {%{"base" => base, "annotation" => annotation}, state}
    end)
  end

  defp encode_value(_kind, value, state), do: {value, state}

  defp placeholder(html, kind, state) do
    token = @token_prefix <> state.nonce <> "x" <> Integer.to_string(state.next) <> "x"
    state = %{state | next: state.next + 1, raws: Map.put(state.raws, token, html)}
    text = %{"type" => "text", "value" => token}

    node =
      if kind == :inlines, do: text, else: %{"type" => "paragraph", "children" => [text]}

    {node, state}
  end

  @doc false
  # Puts the HTML recorded by `encode/3` back in place of its placeholders.
  @spec restore(String.t(), %{String.t() => String.t()}) :: String.t()
  def restore(html, raws) when raws == %{}, do: html

  def restore(html, raws) do
    prefix = raws |> Map.keys() |> hd() |> binary_part(0, 25)
    lookup = fn _, token, _ -> Map.fetch!(raws, token) end

    html =
      Regex.replace(~r/<p(?:\s[^>]*)?>\s*(#{prefix}x(\d+)x)\s*<\/p>/, html, lookup)

    Regex.replace(~r/(#{prefix}x(\d+)x)/, html, lookup)
  end

  defp error(reason),
    do:
      {:error, %CarveError{reason: reason, message: "invalid carve document: #{inspect(reason)}"}}
end

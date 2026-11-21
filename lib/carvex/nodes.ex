# Node structs for the Carve document tree, generated from one table that
# mirrors carve's AST exchange schema (resources/ast-schema.json). The same
# table drives the JSON codec (Carvex.AST), Access, traversal and Enumerable.
#
# Row: {json_type, module, fields, opts}. A field is {field, default} (JSON key
# is the camelized field, kind :scalar), {field, default, kind}, or
# {field, json_key, default, kind}. Every row gets `attrs` and `pos` appended
# unless `opts` sets `attrs: false`.
#
# Kinds: :blocks / :inlines (node lists), :block (one required node), :attrs,
# :pos, :pairs (list of Carvex.RubyPair), :json (opaque decoded JSON), :scalar.

table = [
  {"abbreviation", Carvex.Abbreviation, [abbr: "", expansion: ""], []},
  {"abbreviation_def", Carvex.AbbreviationDef, [abbr: "", expansion: ""], []},
  {"admonition", Carvex.Admonition,
   [{:kind, ""}, {:title, nil, :inlines}, {:label, nil}, {:nodes, "children", [], :blocks}], []},
  {"autolink", Carvex.Autolink, [href: "", text: nil], []},
  {"block_extension", Carvex.BlockExtension,
   [{:name, ""}, {:version, nil}, {:fallback, nil, :block}, {:payload, nil, :json}], []},
  {"block_quote", Carvex.BlockQuote, [{:nodes, "children", [], :blocks}, {:fenced, nil}], []},
  {"caption_number", Carvex.CaptionNumber, [n: nil], []},
  {"cell_wrap", Carvex.CellWrap, [line: 0, row: nil, col: nil], attrs: false},
  {"citation", Carvex.Citation,
   [
     {:key, ""},
     {:prefix, nil, :inlines},
     {:locator, nil, :inlines},
     {:locator_label, nil},
     {:locator_value, nil},
     {:suffix, nil, :inlines},
     {:suppress_author, false},
     {:mode, nil},
     {:number, nil},
     {:use_index, nil}
   ], attrs: false},
  {"citation_definition", Carvex.CitationDefinition,
   [{:key, ""}, {:nodes, "children", [], :inlines}], []},
  {"citation_group", Carvex.CitationGroup,
   [{:nodes, "items", [], :blocks}, {:raw, ""}, {:mode, nil}], []},
  {"code", Carvex.Code, [{:value, ""}, {:cell_wraps, nil, :json}], []},
  {"code_block", Carvex.CodeBlock, [content: "", lang: nil, header: nil, label: nil], []},
  {"comment", Carvex.Comment, [block: false, delimited: nil, form: nil, content: ""], []},
  {"critic_comment", Carvex.CriticComment, [text: ""], []},
  {"definition_description", Carvex.DefinitionDescription, [{:nodes, "children", [], :blocks}],
   []},
  {"definition_list", Carvex.DefinitionList, [{:nodes, "items", [], :blocks}, {:loose, nil}], []},
  {"definition_term", Carvex.DefinitionTerm, [{:nodes, "children", [], :inlines}], []},
  {"delete", Carvex.Delete, [{:nodes, "children", [], :inlines}], []},
  {"directive", Carvex.Directive,
   [{:kind, ""}, {:title, nil, :inlines}, {:nodes, "children", [], :blocks}, {:label, nil}], []},
  {"div", Carvex.Div, [{:nodes, "children", [], :blocks}, {:label, nil}], []},
  {"emphasis", Carvex.Emphasis, [{:nodes, "children", [], :inlines}], []},
  {"escaped_text", Carvex.EscapedText, [value: ""], []},
  {"figure", Carvex.Figure,
   [{:target, nil, :block}, {:caption, [], :inlines}, {:short_caption, nil, :inlines}], []},
  {"figure_group", Carvex.FigureGroup,
   [{:nodes, "children", [], :blocks}, {:caption, nil, :inlines}], []},
  {"footnote", Carvex.Footnote, [{:label, ""}, {:nodes, "children", [], :blocks}], []},
  {"footnote_ref", Carvex.FootnoteRef, [label: "", number: nil], []},
  {"frontmatter", Carvex.Frontmatter, [format: "", content: ""], attrs: false},
  {"hard_break", Carvex.HardBreak, [], []},
  {"heading", Carvex.Heading, [{:level, 1}, {:nodes, "children", [], :inlines}], []},
  {"heading_ref", Carvex.HeadingRef, [target: "", href: nil], []},
  {"highlight", Carvex.Highlight, [{:nodes, "children", [], :inlines}], []},
  {"image", Carvex.Image, [src: "", alt: "", title: nil, ref: nil, resolved: nil, raw_ref: nil],
   []},
  {"inline_extension", Carvex.InlineExtension, [{:name, ""}, {:nodes, "content", [], :inlines}],
   []},
  {"inline_footnote", Carvex.InlineFootnote, [{:nodes, "inline", [], :inlines}, {:number, nil}],
   []},
  {"insert", Carvex.Insert, [{:nodes, "children", [], :inlines}], []},
  {"line_block", Carvex.LineBlock, [{:nodes, "children", [], :blocks}, {:lines, nil, :json}], []},
  {"link", Carvex.Link,
   [
     {:href, ""},
     {:title, nil},
     {:nodes, "children", [], :inlines},
     {:ref, nil},
     {:resolved, nil},
     {:raw_ref, nil}
   ], []},
  {"link_reference_definition", Carvex.LinkReferenceDefinition, [label: "", href: "", title: nil],
   []},
  {"list", Carvex.List,
   [
     {:ordered, false},
     {:tight, false},
     {:nodes, "items", [], :blocks},
     {:start, nil},
     {:ol_type, nil},
     {:delim, nil},
     {:bare_marker, nil},
     {:bullet_char, nil}
   ], []},
  {"list_item", Carvex.ListItem,
   [{:nodes, "children", [], :blocks}, {:checked, nil}, {:task_state, nil}], []},
  {"literal_inline", Carvex.LiteralInline, [content: ""], []},
  {"math", Carvex.Math,
   [
     {:display, false},
     {:content, ""},
     {:cell_wraps, nil, :json},
     {:label, nil},
     {:number, nil}
   ], []},
  {"mention", Carvex.Mention, [user: ""], []},
  {"non_breaking_space", Carvex.NonBreakingSpace, [], []},
  {"paragraph", Carvex.Paragraph, [{:nodes, "children", [], :inlines}, {:block_image, nil}], []},
  {"raw_block", Carvex.RawBlock, [format: "", content: ""], []},
  {"raw_inline", Carvex.RawInline, [{:format, ""}, {:content, ""}, {:cell_wraps, nil, :json}],
   []},
  {"ruby", Carvex.Ruby, [{:pairs, [], :pairs}], []},
  {"section", Carvex.Section, [{:nodes, "children", [], :blocks}, {:level, nil}], []},
  {"small_caps", Carvex.SmallCaps, [{:nodes, "children", [], :inlines}], []},
  {"smart_punctuation", Carvex.SmartPunctuation, [kind: "", value: "", glyph: nil], []},
  {"soft_break", Carvex.SoftBreak, [], []},
  {"span", Carvex.Span, [{:nodes, "children", [], :inlines}], []},
  {"strike", Carvex.Strike, [{:nodes, "children", [], :inlines}], []},
  {"strong", Carvex.Strong, [{:nodes, "children", [], :inlines}, {:bold_italic, nil}], []},
  {"subscript", Carvex.Subscript, [{:nodes, "children", [], :inlines}], []},
  {"substitution", Carvex.Substitution, [{:old, [], :inlines}, {:new, [], :inlines}], []},
  {"superscript", Carvex.Superscript, [{:nodes, "children", [], :inlines}], []},
  {"symbol", Carvex.Symbol, [name: ""], []},
  {"table", Carvex.Table,
   [
     {:nodes, "rows", [], :blocks},
     {:separator_widths, nil, :json},
     {:source_format, nil},
     {:caption, nil, :inlines},
     {:short_caption, nil, :inlines},
     {:columns, nil, :json},
     {:row_groups, nil, :json}
   ], []},
  {"table_cell", Carvex.TableCell,
   [
     {:header, false},
     {:nodes, "children", nil, :inlines},
     {:blocks, nil, :blocks},
     {:span, nil},
     {:colspan, nil},
     {:rowspan, nil},
     {:align, nil},
     {:valign, nil}
   ], []},
  {"table_row", Carvex.TableRow, [{:nodes, "cells", [], :blocks}, {:continuation_lines, nil}],
   []},
  {"tag", Carvex.Tag, [name: ""], []},
  {"text", Carvex.Text, [value: ""], []},
  {"thematic_break", Carvex.ThematicBreak, [marker: nil], []},
  {"underline", Carvex.Underline, [{:nodes, "children", [], :inlines}], []}
]

camel = fn field ->
  [first | rest] = field |> Atom.to_string() |> String.split("_")
  Enum.join([first | Enum.map(rest, &String.capitalize/1)])
end

normalize = fn
  {field, default} -> {field, camel.(field), default, :scalar}
  {field, default, kind} -> {field, camel.(field), default, kind}
  {_, _, _, _} = full -> full
end

table =
  for {type, module, fields, opts} <- table do
    fields = Enum.map(fields, normalize)

    extra =
      if Keyword.get(opts, :attrs, true),
        do: [{:attrs, "attrs", nil, :attrs}, {:pos, "pos", nil, :pos}],
        else: [{:pos, "pos", nil, :pos}]

    {type, module, fields ++ extra}
  end

defmodule Carvex.Pos do
  @moduledoc """
  A node's source span, present when parsed with `parse: [positions: true]`.

  Lines are 1-based. Columns and offsets count Unicode codepoints (not bytes);
  `end_column` and `end_offset` are exclusive.
  """
  defstruct start_line: nil,
            end_line: nil,
            start_column: nil,
            end_column: nil,
            start_offset: nil,
            end_offset: nil,
            file: nil

  @type t :: %__MODULE__{}
end

defmodule Carvex.RubyPair do
  @moduledoc "One base/annotation pair of a `Carvex.Ruby` node."
  use Carvex.Document.Access
  defstruct base: [], annotation: []
  @type t :: %__MODULE__{base: [struct()], annotation: [struct()]}

  defimpl Enumerable do
    def count(_), do: {:error, __MODULE__}
    def member?(_, _), do: {:error, __MODULE__}
    def slice(_), do: {:error, __MODULE__}
    defdelegate reduce(node, acc, fun), to: Carvex.Document.Protocols
  end
end

defmodule Carvex.Raw do
  @moduledoc """
  Raw HTML emitted verbatim in HTML output, regardless of `safe:` or profiles.

  Never produced by the parser; for plugins (build the content with
  `Carvex.safe_html/2`). Non-HTML outputs write it as a raw `html` node.
  """
  use Carvex.Document.Access
  defstruct content: ""
  @type t :: %__MODULE__{content: String.t()}

  defimpl Enumerable do
    def count(_), do: {:error, __MODULE__}
    def member?(_, _), do: {:error, __MODULE__}
    def slice(_), do: {:error, __MODULE__}
    defdelegate reduce(node, acc, fun), to: Carvex.Document.Protocols
  end
end

for {type, module, fields} <- table do
  defmodule module do
    @moduledoc "The Carve `#{type}` node.\n\nFields: " <>
                 Enum.map_join(fields, ", ", fn {f, _, _, _} -> "`#{inspect(f)}`" end) <> "."
    use Carvex.Document.Access
    defstruct Enum.map(fields, fn {field, _, default, _} -> {field, default} end)
    @type t :: %__MODULE__{}

    defimpl Enumerable do
      def count(_), do: {:error, __MODULE__}
      def member?(_, _), do: {:error, __MODULE__}
      def slice(_), do: {:error, __MODULE__}
      defdelegate reduce(node, acc, fun), to: Carvex.Document.Protocols
    end
  end
end

defmodule Carvex.Nodes do
  @moduledoc false

  @child_kinds [:blocks, :inlines, :block, :pairs]

  @modules Enum.map(table, &elem(&1, 1)) ++ [Carvex.Raw, Carvex.RubyPair]

  @doc "Every node module, plus `Carvex.Raw` and `Carvex.RubyPair`."
  def modules, do: @modules

  for {type, module, fields} <- table do
    spec = %{type: type, fields: Enum.map(fields, fn {f, k, _, kind} -> {f, k, kind} end)}
    children = for {f, _, _, kind} <- fields, kind in @child_kinds, do: f

    def spec(unquote(module)), do: unquote(Macro.escape(spec))
    def module_for(unquote(type)), do: unquote(module)
    def child_fields(unquote(module)), do: unquote(children)
  end

  def spec(_), do: nil
  def module_for(_), do: nil
  def child_fields(Carvex.RubyPair), do: [:base, :annotation]
  def child_fields(Carvex.Document), do: [:nodes]
  def child_fields(_), do: []
end

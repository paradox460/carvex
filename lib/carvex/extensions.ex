defmodule Carvex.Extensions do
  @moduledoc false
  # carve-rs built-in extensions by name (the engine's registry keys, snake_cased),
  # with NimbleOptions schemas for the ones that take options. No defaults: an
  # omitted option keeps the engine's default.

  @names ~w(
    autolink citations code_callouts code_group color_swatch details external_links
    fenced_render fenced_render_abc fenced_render_chart fenced_render_d2
    fenced_render_graphviz fenced_render_plantuml fenced_render_vega_lite
    fenced_render_wavedrom glossary heading_level_shift heading_numbers
    heading_permalinks heading_reference img_fence index list_table math_block
    smart_quotes semantic_span spoiler tabs tab_normalize table_of_contents toc wikilinks
  )a

  @schemas %{
    autolink: [allowed_schemes: [type: {:list, :string}]],
    code_group: [
      wrapper_class: [type: :string],
      panel_class: [type: :string],
      label_class: [type: :string],
      radio_class: [type: :string],
      id_prefix: [type: :string]
    ],
    external_links: [target: [type: :string], rel: [type: :string], nofollow: [type: :boolean]],
    heading_level_shift: [shift: [type: {:in, 0..255}]],
    heading_permalinks: [
      symbol: [type: :string],
      css_class: [type: :string],
      aria_label: [type: :string],
      levels: [type: {:list, {:in, 1..6}}],
      prepend: [type: :boolean],
      show_on_hover: [type: :boolean],
      copy_to_clipboard: [type: :boolean],
      lowercase_ids: [type: :boolean]
    ],
    heading_reference: [css_class: [type: :string]],
    math_block: [language: [type: :string]],
    wikilinks: [css_class: [type: :string], new_window: [type: :boolean]],
    heading_numbers: [
      min_level: [type: {:in, 1..6}],
      label: [type: :string],
      crossref: [type: {:in, [:number, :number_title, :title]}]
    ],
    table_of_contents: [
      min_level: [type: {:in, 1..6}],
      max_level: [type: {:in, 1..6}],
      list_type: [type: {:in, [:ul, :ol]}],
      css_class: [type: :string],
      position: [type: {:in, [:top, :bottom]}],
      lowercase_ids: [type: :boolean]
    ],
    tabs: [
      mode: [type: {:in, [:css, :aria]}],
      wrapper_class: [type: :string],
      tab_class: [type: :string],
      label_class: [type: :string],
      radio_class: [type: :string],
      id_prefix: [type: :string]
    ],
    fenced_render: [
      languages: [type: {:list, :string}],
      css_class: [type: :string],
      tag: [type: :string],
      content_mode: [type: {:in, [:text, :json]}],
      wrap_in_figure: [type: :boolean],
      figure_class: [type: :string]
    ],
    img_fence: [
      allow_style: [type: :boolean],
      allow_links: [type: :boolean],
      allow_animation: [type: :boolean],
      allow_external_images: [type: :boolean]
    ]
  }

  @preset_languages %{
    fenced_render_abc: ["abc"],
    fenced_render_chart: ["chart"],
    fenced_render_d2: ["d2"],
    fenced_render_graphviz: ["dot", "graphviz"],
    fenced_render_plantuml: ["plantuml", "puml"],
    fenced_render_vega_lite: ["vega-lite"],
    fenced_render_wavedrom: ["wavedrom"]
  }

  @type t :: [{atom(), keyword()}]

  @doc false
  @spec names() :: [atom()]
  def names, do: @names

  @doc false
  # Normalizes `name | {name, opts}` entries; for a repeated name the last
  # options win, at the first one's position.
  @spec validate!(list()) :: t()
  def validate!(list) when is_list(list) do
    Enum.reduce(list, [], fn entry, acc ->
      {name, opts} = entry!(entry)
      put(acc, name, opts)
    end)
  end

  @doc false
  # Merges `new` into `current` by name: an existing name is replaced in place,
  # new names append.
  @spec merge(t(), t()) :: t()
  def merge(current, new), do: Enum.reduce(new, current, fn {n, o}, acc -> put(acc, n, o) end)

  defp put(acc, name, opts) do
    if Keyword.has_key?(acc, name),
      do:
        Enum.map(acc, fn
          {^name, _} -> {name, opts}
          other -> other
        end),
      else: acc ++ [{name, opts}]
  end

  defp entry!({name, opts}) when is_atom(name) and is_list(opts) do
    name!(name)
    {name, NimbleOptions.validate!(opts, Map.get(@schemas, name, []))}
  end

  defp entry!(name) when is_atom(name), do: entry!({name, []})

  defp entry!(other),
    do: raise(ArgumentError, "invalid carve extension entry: #{inspect(other)}")

  defp name!(name) when name in @names, do: :ok

  defp name!(name) do
    raise ArgumentError,
          "unknown carve extension #{inspect(name)}; supported: #{Enum.map_join(@names, ", ", &inspect/1)}"
  end

  @doc false
  # The NIF's spelling: registry (kebab) keys, option keys as strings, atom values kebab-cased.
  @spec to_native(t()) :: [{String.t(), [{String.t(), term()}]}]
  def to_native(list) do
    Enum.map(list, fn {name, opts} ->
      {kebab(name), Enum.map(opts, fn {key, value} -> {Atom.to_string(key), value(value)} end)}
    end)
  end

  defp value(value) when is_boolean(value), do: value
  defp value(value) when is_atom(value), do: kebab(value)
  defp value(value), do: value

  defp kebab(atom), do: atom |> Atom.to_string() |> String.replace("_", "-")

  @doc false
  # Code block languages that enabled extensions render themselves, so syntax
  # highlighting must leave them alone.
  @spec claimed_languages(t()) :: [String.t()]
  def claimed_languages(list) do
    Enum.flat_map(list, fn
      {:fenced_render, opts} -> Keyword.get(opts, :languages, ["mermaid"])
      {:math_block, opts} -> [Keyword.get(opts, :language, "math")]
      {name, _} -> Map.get(@preset_languages, name, [])
    end)
  end
end

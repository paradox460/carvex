defmodule Carvex.Attributes do
  @moduledoc """
  A node's attributes, as carve's AST carries them.

    * `id` - the `#id`, or `nil`
    * `classes` - the `.class` names, in order
    * `key_values` - other `key=value` pairs (string keys)
    * `order` - the written order of the slots, as `"#id"`, `".class"` or a
      key name; `[]` when not recorded. Used by `Carvex.to_carve/2`.

  Every function accepts `nil` as an empty set and returns a struct.
  """

  defstruct id: nil, classes: [], key_values: %{}, order: []

  @type t :: %__MODULE__{
          id: String.t() | nil,
          classes: [String.t()],
          key_values: %{String.t() => String.t()},
          order: [String.t()]
        }

  @doc """
  Returns the value for `key`: the id for `"id"`, the classes joined with a
  space for `"class"`, otherwise the key/value entry. `nil` when absent.

      iex> attrs = %Carvex.Attributes{id: "x", classes: ["a", "b"], key_values: %{"k" => "v"}}
      iex> Carvex.Attributes.get(attrs, "class")
      "a b"
      iex> Carvex.Attributes.get(attrs, "id")
      "x"
      iex> Carvex.Attributes.get(attrs, "k")
      "v"
      iex> Carvex.Attributes.get(nil, "class")
      nil
  """
  @spec get(t() | nil, String.t()) :: String.t() | nil
  def get(nil, _key), do: nil
  def get(%__MODULE__{id: id}, "id"), do: id
  def get(%__MODULE__{classes: []}, "class"), do: nil
  def get(%__MODULE__{classes: classes}, "class"), do: Enum.join(classes, " ")
  def get(%__MODULE__{key_values: kv}, key), do: Map.get(kv, key)

  @doc """
  Sets `key`. `"class"` replaces the classes with the whitespace-split value.

      iex> Carvex.Attributes.put(nil, "class", "a b")
      %Carvex.Attributes{classes: ["a", "b"]}
      iex> Carvex.Attributes.put(%Carvex.Attributes{id: "x", order: ["#id"]}, "k", "v")
      %Carvex.Attributes{id: "x", key_values: %{"k" => "v"}, order: ["#id", "k"]}
  """
  @spec put(t() | nil, String.t(), String.t()) :: t()
  def put(attrs, key, value) do
    attrs = attrs || %__MODULE__{}

    attrs =
      case key do
        "id" -> %{attrs | id: value}
        "class" -> %{attrs | classes: String.split(value)}
        key -> %{attrs | key_values: Map.put(attrs.key_values, key, value)}
      end

    add_slot(attrs, slot(key))
  end

  @doc """
  Removes `key`.

      iex> Carvex.Attributes.delete(%Carvex.Attributes{id: "x", classes: ["a"], order: ["#id", ".class"]}, "class")
      %Carvex.Attributes{id: "x", order: ["#id"]}
  """
  @spec delete(t() | nil, String.t()) :: t()
  def delete(attrs, key) do
    attrs = attrs || %__MODULE__{}

    attrs =
      case key do
        "id" -> %{attrs | id: nil}
        "class" -> %{attrs | classes: []}
        key -> %{attrs | key_values: Map.delete(attrs.key_values, key)}
      end

    %{attrs | order: Elixir.List.delete(attrs.order, slot(key))}
  end

  @doc """
  Appends a class.

      iex> Carvex.Attributes.add_class(%Carvex.Attributes{classes: ["a"]}, "b")
      %Carvex.Attributes{classes: ["a", "b"]}
  """
  @spec add_class(t() | nil, String.t()) :: t()
  def add_class(attrs, class) do
    attrs = attrs || %__MODULE__{}
    add_slot(%{attrs | classes: attrs.classes ++ [class]}, ".class")
  end

  @doc """
  True for `nil` or an attribute set with nothing in it.

      iex> Carvex.Attributes.empty?(nil)
      true
      iex> Carvex.Attributes.empty?(%Carvex.Attributes{id: "x"})
      false
  """
  @spec empty?(t() | nil) :: boolean()
  def empty?(nil), do: true
  def empty?(%__MODULE__{} = attrs), do: attrs == %__MODULE__{}

  defp slot("id"), do: "#id"
  defp slot("class"), do: ".class"
  defp slot(key), do: key

  defp add_slot(%__MODULE__{order: []} = attrs, _slot), do: attrs

  defp add_slot(%__MODULE__{order: order} = attrs, slot) do
    if slot in order, do: attrs, else: %{attrs | order: order ++ [slot]}
  end
end

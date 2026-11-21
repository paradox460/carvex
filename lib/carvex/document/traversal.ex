defmodule Carvex.Document.Traversal do
  @moduledoc false
  # Ported from MDEx.Document.Traversal (MIT, https://github.com/leandrocp/mdex),
  # itself based on https://github.com/philss/floki/blob/96955f925d62989b6f0bfaf09ce6505e67e04fbb/lib/floki/traversal.ex
  #
  # Walks every child field of a node (Carvex.Nodes.child_fields/1) in order,
  # post-order. List fields drop children mapped to `nil`/`:pop`; single-node
  # fields (`Carvex.Figure.target`, `Carvex.BlockExtension.fallback`) cannot be removed.

  alias Carvex.Nodes

  def traverse_and_update(node, fun), do: fun.(map_children(node, fun))

  def traverse_and_update(node, acc, fun) do
    {node, acc} = map_children(node, acc, fun)
    fun.(node, acc)
  end

  defp map_children(%module{} = node, fun) do
    Enum.reduce(Nodes.child_fields(module), node, fn field, node ->
      case Map.fetch!(node, field) do
        nil -> node
        list when is_list(list) -> Map.put(node, field, map_list(list, fun))
        child -> Map.put(node, field, single!(traverse_and_update(child, fun), field, module))
      end
    end)
  end

  defp map_children(node, _fun), do: node

  defp map_list([], _fun), do: []

  defp map_list([node | rest], fun) do
    case traverse_and_update(node, fun) do
      removed when removed in [nil, :pop] -> map_list(rest, fun)
      mapped -> [mapped | map_list(rest, fun)]
    end
  end

  defp map_children(%module{} = node, acc, fun) do
    Enum.reduce(Nodes.child_fields(module), {node, acc}, fn field, {node, acc} ->
      case Map.fetch!(node, field) do
        nil ->
          {node, acc}

        list when is_list(list) ->
          {list, acc} = map_list(list, acc, fun)
          {Map.put(node, field, list), acc}

        child ->
          {child, acc} = traverse_and_update(child, acc, fun)
          {Map.put(node, field, single!(child, field, module)), acc}
      end
    end)
  end

  defp map_children(node, acc, _fun), do: {node, acc}

  defp map_list([], acc, _fun), do: {[], acc}

  defp map_list([node | rest], acc, fun) do
    case traverse_and_update(node, acc, fun) do
      {removed, acc} when removed in [nil, :pop] ->
        map_list(rest, acc, fun)

      {mapped, acc} ->
        {rest, acc} = map_list(rest, acc, fun)
        {[mapped | rest], acc}
    end
  end

  defp single!(%_{} = node, _field, _module), do: node

  defp single!(_, field, module),
    do: raise(ArgumentError, "cannot remove #{field} of #{inspect(module)}")
end

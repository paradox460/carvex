defmodule Carvex.Document.Protocols do
  @moduledoc false
  # Enumerable walks a document or node in pre-order, root included. Each node
  # module in lib/carvex/nodes.ex delegates its Enumerable `reduce/3` here.

  alias Carvex.Nodes

  def reduce(node, acc, fun), do: do_reduce([node], acc, fun)

  defp do_reduce(_, {:halt, acc}, _fun), do: {:halted, acc}
  defp do_reduce(stack, {:suspend, acc}, fun), do: {:suspended, acc, &do_reduce(stack, &1, fun)}
  defp do_reduce([], {:cont, acc}, _fun), do: {:done, acc}

  defp do_reduce([node | rest], {:cont, acc}, fun) do
    do_reduce(children(node) ++ rest, fun.(node, acc), fun)
  end

  defp children(%module{} = node) do
    Enum.flat_map(Nodes.child_fields(module), fn field ->
      case Map.fetch!(node, field) do
        nil -> []
        list when is_list(list) -> list
        child -> [child]
      end
    end)
  end

  defp children(_), do: []
end

defimpl Enumerable, for: Carvex.Document do
  def count(_), do: {:error, __MODULE__}
  def member?(_, _), do: {:error, __MODULE__}
  def slice(_), do: {:error, __MODULE__}
  defdelegate reduce(node, acc, fun), to: Carvex.Document.Protocols
end

defimpl Collectable, for: Carvex.Document do
  def into(doc) do
    collector = fn
      acc, {:cont, node} -> [node | acc]
      acc, :done -> %{doc | nodes: doc.nodes ++ Enum.reverse(acc)}
      _acc, :halt -> :ok
    end

    {[], collector}
  end
end

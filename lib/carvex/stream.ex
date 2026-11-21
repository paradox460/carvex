defmodule Carvex.Stream do
  @moduledoc false
  # Each chunk re-parses the whole buffer: reference links and footnotes
  # resolve document-wide, so a later chunk can change an earlier block.

  alias Carvex.Document

  def stream(enumerable, opts \\ []) do
    if Keyword.has_key?(opts, :source) do
      raise ArgumentError, "Carvex.stream/2 does not accept :source"
    end

    Stream.transform(
      enumerable,
      fn -> %{base: Carvex.new(opts), buffer: "", pending: "", emitted: %{}} end,
      &reduce/2,
      &last/1,
      fn _ -> :ok end
    )
  end

  defp reduce(chunk, st) do
    {valid, pending} =
      case :unicode.characters_to_binary(st.pending <> chunk) do
        valid when is_binary(valid) -> {valid, ""}
        {:incomplete, valid, rest} -> {valid, rest}
        {:error, _, _} -> raise ArgumentError, "invalid UTF-8 in carve stream"
      end

    buffer = st.buffer <> valid
    blocks = parse!(buffer, st.base)
    count = length(blocks)

    {changed, emitted} =
      blocks
      |> Enum.with_index()
      |> Enum.reduce({[], st.emitted}, fn {node, i}, {out, emitted} ->
        if Map.get(emitted, i) == node do
          {out, emitted}
        else
          {[{i, run(st.base, i, [node])} | out], Map.put(emitted, i, node)}
        end
      end)

    {removed, emitted} =
      emitted
      |> Enum.filter(fn {i, value} -> i >= count and value != :removed end)
      |> Enum.sort()
      |> Enum.reduce({[], emitted}, fn {i, _}, {out, emitted} ->
        {[{i, run(st.base, i, [])} | out], Map.put(emitted, i, :removed)}
      end)

    {Enum.reverse(changed) ++ Enum.reverse(removed),
     %{st | buffer: buffer, pending: pending, emitted: emitted}}
  end

  defp last(%{pending: ""} = st), do: {[], st}
  defp last(_st), do: raise(ArgumentError, "incomplete UTF-8 at end of carve stream")

  defp parse!(buffer, base) do
    with {:ok, json} <- Carvex.Native.parse(buffer, Carvex.Renderer.native_options(base)),
         {:ok, nodes} <- Carvex.AST.decode(json) do
      nodes
    else
      {:error, %Carvex.CarveError{} = e} -> raise e
      {:error, reason} -> raise Carvex.CarveError.native(reason)
    end
  end

  defp run(base, id, nodes) do
    case Document.run(Document.put_private(%{base | nodes: nodes}, :stream, %{id: id})) do
      {_doc, exception} -> raise exception
      doc -> doc
    end
  end
end

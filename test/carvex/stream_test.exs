defmodule Carvex.StreamTest do
  use ExUnit.Case, async: true

  test "emits changed blocks by id" do
    result =
      ["# Hel", "lo\n\nPara", "graph\n"]
      |> Carvex.stream()
      |> Enum.map(fn {id, doc} -> {id, Carvex.to_html!(doc)} end)

    assert result == [
             {0, Carvex.to_html!("# Hel")},
             {0, Carvex.to_html!("# Hello")},
             {1, Carvex.to_html!("Para")},
             {1, Carvex.to_html!("Paragraph")}
           ]
  end

  test "per-block documents carry their stream id" do
    plugin = fn doc ->
      Carvex.Document.append_steps(doc,
        tag: fn d ->
          %{id: id} = Carvex.Document.get_private(d, :stream)

          Carvex.Document.put_node_in_document_root(
            d,
            %Carvex.Raw{content: "<b id=\"b-#{id}\"></b>"},
            :bottom
          )
        end
      )
    end

    assert ["a\n\nb"]
           |> Carvex.stream(plugins: [plugin])
           |> Enum.map(fn {id, d} -> {id, Carvex.to_html!(d)} end) == [
             {0, "<p>a</p>\n<b id=\"b-0\"></b>"},
             {1, "<p>b</p>\n<b id=\"b-1\"></b>"}
           ]
  end

  test "plugins attach once and run per block" do
    plugin = fn doc ->
      Carvex.Document.append_steps(doc,
        up: fn d ->
          Carvex.Document.update_nodes(d, Carvex.Text, &%{&1 | value: String.upcase(&1.value)})
        end
      )
    end

    assert [{0, doc}] = ["hi"] |> Carvex.stream(plugins: [plugin]) |> Enum.to_list()
    assert Carvex.to_html!(doc) == "<p>HI</p>"
  end

  test "multi-byte characters split across chunks" do
    assert [{0, doc}] = [<<0xC3>>, <<0xA9>>] |> Carvex.stream() |> Enum.to_list()
    assert doc[Carvex.Text] == [%Carvex.Text{value: "é"}]
  end

  test "incomplete UTF-8 at the end raises" do
    assert_raise ArgumentError, "incomplete UTF-8 at end of carve stream", fn ->
      [<<0xC3>>] |> Carvex.stream() |> Enum.to_list()
    end
  end

  test "rejects :source" do
    assert_raise ArgumentError, fn -> Carvex.stream(["x"], source: "y") end
  end
end

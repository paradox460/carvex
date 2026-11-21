defmodule CarvexTest do
  use ExUnit.Case, async: true
  doctest Carvex
  doctest Carvex.Attributes
  doctest Carvex.Document
  doctest Carvex.Sigil

  @corpus File.read!("test/fixtures/corpus.crv")

  describe "AST round trip" do
    for target <- [:html, :markdown, :plain_text, :ansi, :carve] do
      test "#{target}: rendering a parsed document matches rendering the source" do
        render = &Carvex.Renderer.render(Carvex.document(&1, []), unquote(target), false)
        assert {:ok, fast} = render.(@corpus)
        assert {:ok, ^fast} = render.(Carvex.parse_document!(@corpus))
      end
    end

    test "invalid nodes return an error" do
      assert {:error, %Carvex.CarveError{reason: {:invalid_node, %{not: :a_node}}}} =
               Carvex.to_html(Carvex.Document.wrap(%{not: :a_node}))
    end
  end

  describe "Carvex.Raw" do
    setup do
      doc =
        Carvex.Document.wrap([
          %Carvex.Raw{content: "<x-block></x-block>"},
          %Carvex.Paragraph{nodes: [%Carvex.Text{value: "a"}, %Carvex.Raw{content: "<i>b</i>"}]}
        ])

      %{doc: doc}
    end

    for opts <- [[], [render: [safe: true]], [render: [profile: :comment]]] do
      test "renders verbatim in block and inline position with #{inspect(opts)}", %{doc: doc} do
        html = Carvex.to_html!(doc, unquote(opts))
        assert html =~ "<x-block></x-block>"
        refute html =~ "<p><x-block>"
        assert html =~ "<p>a<i>b</i></p>"
        refute html =~ "carvexraw"
      end
    end

    test "is a raw html node in other outputs", %{doc: doc} do
      assert Carvex.to_carve!(doc) == "```=html\n<x-block></x-block>\n```\n\na`<i>b</i>`{=html}\n"
    end
  end

  describe "~CRV sigil" do
    use Carvex

    test "HTML modifier" do
      assert ~CRV"*a*"HTML == "<p><strong>a</strong></p>"
    end

    test "no modifier returns a document" do
      assert %Carvex.Document{nodes: [%Carvex.Paragraph{}]} = ~CRV"x"
    end
  end
end

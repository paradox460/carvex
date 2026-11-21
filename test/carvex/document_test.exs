defmodule Carvex.DocumentTest do
  use ExUnit.Case, async: true

  alias Carvex.Document

  defmodule ShoutPlugin do
    alias Carvex.Document

    def attach(doc, opts) do
      doc
      |> Document.register_options([:shout])
      |> Document.put_options(opts)
      |> Document.append_steps(shout: &shout/1)
    end

    defp shout(doc) do
      if Document.get_option(doc, :shout) do
        Document.update_nodes(doc, Carvex.Text, &%{&1 | value: String.upcase(&1.value)})
      else
        doc
      end
    end
  end

  describe "pipeline" do
    test "plugins register options and run steps" do
      assert Carvex.to_html!("hi", plugins: [{ShoutPlugin, shout: true}]) == "<p>HI</p>"
      assert Carvex.to_html!("hi", plugins: [ShoutPlugin]) == "<p>hi</p>"
    end

    test "plugins attach before other options in the same call" do
      assert Carvex.to_html!("hi", shout: true, plugins: [ShoutPlugin]) == "<p>HI</p>"
    end

    test "unknown options raise" do
      assert_raise ArgumentError, "unknown option :nope", fn ->
        Carvex.new() |> Document.put_options(nope: 1)
      end
    end

    test "halt stops later steps and the document still renders" do
      html =
        Carvex.new(source: "hi")
        |> Document.append_steps(stop: &Document.halt/1, boom: fn _ -> raise "not reached" end)
        |> Carvex.to_html!()

      assert html == "<p>hi</p>"
    end

    test "halt with an exception returns an error" do
      doc =
        Carvex.new(source: "hi")
        |> Document.append_steps(fail: &Document.halt(&1, %RuntimeError{message: "nope"}))

      assert {:error, %RuntimeError{message: "nope"}} = Carvex.to_html(doc)
    end

    test "mfa steps receive the document first" do
      doc =
        Carvex.new()
        |> Document.append_steps(
          add: {Document, :put_node_in_document_root, [%Carvex.Text{value: "x"}, :bottom]}
        )
        |> Document.prepend_steps(first: {Document, :put_private, [:seen, true]})
        |> Document.run()

      assert doc.nodes == [%Carvex.Text{value: "x"}]
      assert Document.get_private(doc, :seen)
      assert doc.current_steps == []
    end

    test "options merge and validate" do
      doc =
        Carvex.new(render: [safe: true], parse: [positions: true])
        |> Document.put_render_options(sections: false)
        |> Document.put_parse_options(ascii_heading_ids: :fold)
        |> Document.assign(:a, 1)
        |> Document.assign(b: 2)

      render = Document.get_option(doc, :render)
      assert render[:safe] == true
      assert render[:sections] == false
      assert render[:mode] == :interactive

      assert Enum.sort(Document.get_option(doc, :parse)) ==
               [ascii_heading_ids: :fold, lowercase_heading_ids: false, positions: true]

      assert Document.get_option(doc, :assigns) == %{a: 1, b: 2}

      assert_raise NimbleOptions.ValidationError, fn ->
        Document.put_render_options(doc, mode: :fancy)
      end

      doc = Document.put_syntax_highlight_options(doc, engine: :syntect, opts: [theme: "x"])
      doc = Document.put_syntax_highlight_options(doc, opts: [pre_class: "p"])

      assert Enum.sort(Document.get_option(doc, :syntax_highlight)) == [
               engine: :syntect,
               opts: [theme: "x", pre_class: "p"]
             ]

      assert doc
             |> Document.put_syntax_highlight_options(nil)
             |> Document.get_option(:syntax_highlight) == nil
    end

    test "extensions merge by name" do
      doc =
        Carvex.new(extensions: [:toc, heading_permalinks: [symbol: "#"]])
        |> Document.put_extensions([:spoiler, heading_permalinks: [symbol: "§"]])

      assert Document.get_option(doc, :extensions) ==
               [toc: [], heading_permalinks: [symbol: "§"], spoiler: []]
    end
  end

  describe "access and enumerable" do
    setup do
      %{doc: Carvex.parse_document!("Hello *world* and *more*")}
    end

    test "fetch by module, atom, struct, and function", %{doc: doc} do
      assert [%Carvex.Strong{}, %Carvex.Strong{}] = doc[Carvex.Strong]
      assert Enum.map(doc[:text], & &1.value) == ["Hello ", "world", " and ", "more"]
      assert [%Carvex.Text{value: "more"}] = doc[%Carvex.Text{value: "more"}]
      assert [%Carvex.Paragraph{}] = doc[&match?(%Carvex.Paragraph{}, &1)]
      assert doc[Carvex.Heading] == nil
      assert %Carvex.Document{} = doc[0]
    end

    test "invalid selector raises", %{doc: doc} do
      assert_raise ArgumentError, "invalid selector: nil", fn -> doc[nil] end
    end

    test "pop removes the first match", %{doc: doc} do
      {popped, doc} = pop_in(doc[Carvex.Strong])
      assert popped == %Carvex.Strong{nodes: [%Carvex.Text{value: "world"}]}
      assert Carvex.to_html!(doc) == "<p>Hello  and <strong>more</strong></p>"
    end

    test "get_and_update touches the first match", %{doc: doc} do
      {old, doc} = get_and_update_in(doc[Carvex.Text], &{&1.value, %{&1 | value: "Bye "}})
      assert old == "Hello "
      assert Carvex.to_html!(doc) == "<p>Bye <strong>world</strong> and <strong>more</strong></p>"
    end

    test "enumerates pre-order including the root", %{doc: doc} do
      assert Enum.count(doc) == 8

      assert [%Carvex.Document{}, %Carvex.Paragraph{}, %Carvex.Text{value: "Hello "} | _] =
               Enum.to_list(doc)
    end

    test "collectable appends nodes", %{doc: doc} do
      doc = Enum.into([%Carvex.Paragraph{nodes: [%Carvex.Text{value: "end"}]}], doc)
      assert List.last(doc.nodes) == %Carvex.Paragraph{nodes: [%Carvex.Text{value: "end"}]}
    end
  end

  describe "single-node child fields" do
    setup do
      %{doc: Carvex.parse_document!("![a](b.png)\n^ cap\n")}
    end

    test "access reaches a figure target", %{doc: doc} do
      assert [%Carvex.Image{src: "b.png"}] = doc[Carvex.Image]
    end

    test "a figure target cannot be removed", %{doc: doc} do
      assert_raise ArgumentError, "cannot remove target of Carvex.Figure", fn ->
        Carvex.traverse_and_update(doc, fn
          %Carvex.Image{} -> nil
          node -> node
        end)
      end
    end
  end
end

# test/fixtures/ast-schema.json is carve's resources/ast-schema.json at
# markup-carve/carve commit 04bfdf309c66f951af12728d2d4eb5453b647c33.
defmodule Carvex.ASTTest do
  use ExUnit.Case, async: true

  @schema "test/fixtures/ast-schema.json" |> File.read!() |> JSON.decode!()
  @corpus File.read!("test/fixtures/corpus.crv")

  test "every schema node type has a struct with exactly its fields" do
    types =
      for {_name, %{"properties" => %{"type" => %{"const" => type}} = props}} <- @schema["$defs"],
          type != "document",
          do: {type, props |> Map.keys() |> Elixir.List.delete("type") |> Enum.sort()}

    assert length(types) == length(Carvex.Nodes.modules()) - 2

    for {type, keys} <- types do
      module = Carvex.Nodes.module_for(type)
      assert module, "no struct for #{type}"
      spec_keys = Carvex.Nodes.spec(module).fields |> Enum.map(&elem(&1, 1)) |> Enum.sort()
      assert spec_keys == keys, "fields differ for #{type}"
    end
  end

  for positions <- [false, true] do
    test "decode then encode is the identity on the corpus (positions: #{positions})" do
      doc = Carvex.new(parse: [positions: unquote(positions)])
      {:ok, json} = Carvex.Native.parse(@corpus, Carvex.Renderer.native_options(doc))
      {:ok, nodes} = Carvex.AST.decode(json)
      {:ok, json2, raws} = Carvex.AST.encode(nodes, :html, false)
      assert raws == %{}
      assert JSON.decode!(json2)["children"] == JSON.decode!(json)["children"]
    end
  end

  test "parse shape" do
    assert Carvex.parse_document!("Hello *world*").nodes == [
             %Carvex.Paragraph{
               nodes: [
                 %Carvex.Text{value: "Hello "},
                 %Carvex.Strong{nodes: [%Carvex.Text{value: "world"}]}
               ]
             }
           ]
  end

  test "unknown types and fields are errors" do
    assert {:error, %Carvex.CarveError{reason: {:unknown_ast_type, "nope"}}} =
             Carvex.AST.decode(
               ~s({"type":"document","srcByteLength":0,"children":[{"type":"nope"}]})
             )

    assert {:error, %Carvex.CarveError{reason: {:unknown_ast_field, "text", "x"}}} =
             Carvex.AST.decode(
               ~s({"type":"document","srcByteLength":0,"children":[{"type":"text","value":"a","x":1}]})
             )
  end
end

defmodule Carvex.CarveOptionsTest do
  use ExUnit.Case, async: true

  test "the extension list matches the engine registry" do
    assert Carvex.extensions() == Carvex.Extensions.names()
  end

  describe "extensions" do
    test "options reach the engine" do
      assert Carvex.to_html!("# A", extensions: [heading_permalinks: [symbol: "§"]]) =~ "§"
      refute Carvex.to_html!("# A") =~ "§"
    end

    test "apply to edited documents" do
      doc = Carvex.parse_document!("# A")
      assert Carvex.to_html!(doc, extensions: [heading_permalinks: [symbol: "§"]]) =~ "§"
    end

    test "invalid names and options raise" do
      assert_raise ArgumentError, ~r/unknown carve extension :nope/, fn ->
        Carvex.new(extensions: [:nope])
      end

      assert_raise NimbleOptions.ValidationError, fn ->
        Carvex.new(extensions: [tabs: [mode: :bogus]])
      end

      assert_raise NimbleOptions.ValidationError, fn ->
        Carvex.new(extensions: [details: [x: 1]])
      end
    end
  end

  test "safe escapes raw html" do
    html = Carvex.to_html!("`<b>x</b>`{=html}", render: [safe: true])
    refute html =~ "<b>x</b>"
    assert html =~ "&lt;b&gt;"
  end

  describe "profiles" do
    test "drop disallowed constructs" do
      refute Carvex.to_html!("# Head", render: [profile: :comment]) =~ "<h1"

      refute Carvex.to_html!(Carvex.parse_document!("# Head"), render: [profile: :comment]) =~
               "<h1"
    end

    test "reject over-length input" do
      long = String.duplicate("a", 10_001)

      for input <- [long, Carvex.parse_document!(long)] do
        assert {:error, %Carvex.CarveError{reason: {:profile_violation, _}}} =
                 Carvex.to_html(input, render: [profile: :minimal])
      end
    end
  end

  test "sections" do
    refute Carvex.to_html!("# A\n\nb", render: [sections: false]) =~ "<section"
    assert Carvex.to_html!("# A\n\nb") =~ ~s(<section id="A">)
  end

  test "symbols" do
    assert Carvex.to_html!("Ship :rocket:", render: [symbols: %{"rocket" => "🚀"}]) =~ "🚀"
  end

  test "to_carve writes canonical source" do
    assert "# Title\n" <> _ = Carvex.to_carve!("#  Title\n\n/a/ *b*")
  end

  test "lint" do
    src = "{#orphan .cls}\n\n"

    assert [%Carvex.LintWarning{rule: "unattached-block-attribute", line: 1} = w] =
             Carvex.lint(src)

    assert binary_part(src, w.start_offset, w.end_offset - w.start_offset) == "{#orphan .cls}"
  end
end

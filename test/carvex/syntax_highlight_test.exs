defmodule Carvex.SyntaxHighlightTest do
  use ExUnit.Case, async: true

  test "decorators are stripped without highlighting; pre_class becomes a class" do
    src = "{pre_class=x theme=y}\n```ex\na\n```\n"
    html = Carvex.to_html!(src)
    assert html == ~s(<pre class="x"><code class="language-ex">a\n</code></pre>)
    refute html =~ "theme="
    refute html =~ "pre_class"
    assert Carvex.to_html!(Carvex.parse_document!(src)) == html
  end

  test "highlight_lines parsing skips invalid tokens" do
    assert Carvex.SyntaxHighlight.parse_lines("1, 3-5,x,4-2,0, 7 ") == [{1, 1}, {3, 5}, {7, 7}]
    assert Carvex.SyntaxHighlight.parse_lines("nope") == []
  end

  describe "syntect" do
    @src "{highlight_lines=\"2\" #c}\n```elixir\na = 1\nb = 2\n```\n"

    test "highlights with line numbers and highlighted lines" do
      html = Carvex.to_html!(@src, syntax_highlight: [engine: :syntect])
      assert html =~ ~s(<pre class="syntect")
      assert html =~ ~s( id="c")
      assert html =~ ~s(<code class="language-elixir">)
      assert html =~ ~r/<span class="line highlighted" data-line="2" style="[^"]+">/
      assert html =~ ~s(<span class="line" data-line="1">)
      refute html =~ "highlight_lines="
    end

    test "highlighted output is not gated by safe:" do
      html = Carvex.to_html!(@src, syntax_highlight: [engine: :syntect], render: [safe: true])
      assert html =~ ~s(<pre class="syntect")
    end

    test "code blocks without a language are left alone" do
      html = Carvex.to_html!("```\nx\n```\n", syntax_highlight: [engine: :syntect])
      assert html == "<pre><code>x\n</code></pre>"
    end

    test "reaches code blocks nested in containers" do
      html = Carvex.to_html!("- ```elixir\n  x\n  ```\n", syntax_highlight: [engine: :syntect])
      assert html =~ ~s(<pre class="syntect")
    end

    test "themes" do
      themes = Carvex.Native.syntect_themes()
      assert "InspiredGitHub" in themes

      assert {:error, %Carvex.CarveError{reason: {:highlight, "unknown syntect theme: nope"}}} =
               Carvex.to_html(@src, syntax_highlight: [engine: :syntect, opts: [theme: "nope"]])
    end

    test "theme and pre_class from decorators and options" do
      src = "{theme=Dracula pre_class=deco .cls}\n```elixir\nx\n```\n"
      html = Carvex.to_html!(src, syntax_highlight: [engine: :syntect, opts: [pre_class: "opt"]])

      assert html =~
               ~s(<pre class="syntect opt deco cls" style="color:#f8f8f2;background-color:#282a36;")
    end

    test "languages claimed by extensions are not highlighted" do
      html =
        Carvex.to_html!("```mermaid\ngraph TD\n```\n",
          extensions: [:fenced_render],
          syntax_highlight: [engine: :syntect]
        )

      refute html =~ ~s(class="syntect)
      assert html =~ "mermaid"
    end
  end

  describe "lumis" do
    @describetag :lumis

    test "highlights code blocks" do
      html = Carvex.to_html!("```elixir\nx = 1\n```\n", syntax_highlight: [engine: :lumis])
      assert html =~ ~s(class="lumis)
    end

    test "highlight_lines decorator" do
      src =
        "{highlight_lines=\"1\" highlight_lines_style=\"background: red\"}\n```elixir\nx = 1\ny = 2\n```\n"

      html = Carvex.to_html!(src, syntax_highlight: [engine: :lumis])
      assert html =~ ~r/<span class="l-line" style="[^"]*background: red" data-line="1">/
    end
  end
end

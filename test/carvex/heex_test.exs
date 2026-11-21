defmodule Carvex.HEExTest do
  use ExUnit.Case, async: true
  use Carvex
  import Phoenix.Component

  alias Carvex.HEEx.Preprocessor

  defp to_s(rendered), do: rendered |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()

  describe "preprocessor" do
    test "inline expressions" do
      assert Preprocessor.rewrite("a {@x} b") == "a `{@x}`{=heex} b"
      assert Preprocessor.rewrite("a {@m[\"}\"]} b") == "a `{@m[\"}\"]}`{=heex} b"
      assert Preprocessor.rewrite("a <%= 1 %> b") == "a `<%= 1 %>`{=heex} b"

      assert Preprocessor.rewrite("a <.icon name=\"x\" /> b") ==
               "a `<.icon name=\"x\" />`{=heex} b"
    end

    test "carve brace syntax is untouched" do
      for src <- [
            "[a]{.c}",
            "[Tab]{kbd}",
            "=m=",
            "`{@x}`",
            "{#id}",
            "{key=v}",
            "{_e_}",
            "a { b",
            "\\{@x}",
            "{% c %}",
            "{,sub,}",
            "{^sup^}",
            "{:fr}",
            "{{ x }}",
            "{~old~>new~}",
            "{+ins+}",
            "|{> .num} 12 |",
            "{loose}\n- a\n",
            "{table header-rows=0}\n```csv\na\n```\n"
          ] do
        assert Preprocessor.rewrite(src) == src
      end
    end

    test "an expression alone on a line is a raw heex block" do
      assert Preprocessor.rewrite("{@x}\n") == "```=heex\n{@x}\n```\n\n"
    end

    test "block constructs become raw heex blocks" do
      assert Preprocessor.rewrite("text\n<.card title=\"a>b\">\nbody\n</.card>\n") ==
               "text\n\n```=heex\n<.card title=\"a>b\">\n```\n\nbody\n\n```=heex\n</.card>\n```\n\n"
    end

    test "backticks inside constructs widen the fence" do
      assert Preprocessor.rewrite("a {@x <> \"`\"} b") == "a ``{@x <> \"`\"}``{=heex} b"
      assert Preprocessor.rewrite("a <%= \"`\" %> b `x`") == "a ``<%= \"`\" %>``{=heex} b `x`"
    end

    test "fenced code is untouched" do
      src = "```\n<.card>{@x}\n```\n~~~~\n{@y}\n~~~~\n"
      assert Preprocessor.rewrite(src) == src
    end
  end

  describe "~CRV HEEX" do
    test "renders expressions and components" do
      assigns = %{name: "Ann"}

      html =
        to_s(~CRV"""
        Hi {@name}

        <.link href="/x">go</.link>
        """HEEX)

      assert html =~ "Hi Ann"
      assert html =~ ~s(<a href="/x">go</a>)
    end
  end

  describe "to_heex" do
    test "assigns and text braces" do
      # Literal braces render as entities, which browsers display as `{`.
      assert "a { b" |> Carvex.to_heex!(assigns: %{}) |> to_s() == "<p>a &lbrace; b</p>"
      html = "Hello {@who} `{code}`" |> Carvex.to_heex!(assigns: %{who: "W"}) |> to_s()
      assert html == "<p>Hello W <code>&lbrace;code&rbrace;</code></p>"
    end

    test "highlighted code escapes braces" do
      html =
        "```elixir\n%{a: 1}\n```\n"
        |> Carvex.to_heex!(syntax_highlight: [engine: :syntect])
        |> to_s()

      assert html =~ "%&lbrace;"
      assert html =~ "&rbrace;"
    end

    test "script and style contents keep their braces" do
      html =
        "```=html\n<script>if (a) { b() }</script>\n```\n\nx { y }\n"
        |> Carvex.to_heex!()
        |> to_s()

      assert html =~ "<script>if (a) { b() }</script>"
      assert html =~ "x &lbrace; y &rbrace;"
    end

    test "sanitize is rejected" do
      assert {:error, %Carvex.CarveError{reason: :sanitize_unsupported_in_heex}} =
               Carvex.to_heex("x", sanitize: Carvex.Document.default_sanitize_options())
    end

    test "documents" do
      doc = Carvex.parse_document!("x") |> Carvex.Document.assign(:y, 1)
      assert to_s(Carvex.to_heex!(doc)) == "<p>x</p>"
    end

    test "steps see :heex and can emit brace-safe raw html" do
      plugin = fn doc ->
        Carvex.Document.append_steps(doc,
          diagram: fn doc ->
            heex? = Carvex.Document.get_private(doc, :heex, false)

            Carvex.Document.update_nodes(doc, %Carvex.CodeBlock{lang: "diagram"}, fn block ->
              content = Carvex.safe_html(block.content, sanitize: nil, escape: true, heex: heex?)
              %Carvex.Raw{content: ~s(<pre class="diagram">#{content}</pre>)}
            end)
          end
        )
      end

      src = "```diagram\nA{yes}-->B\n```\n"
      html = src |> Carvex.to_heex!(plugins: [plugin]) |> to_s()
      assert html == ~s(<pre class="diagram">A&lbrace;yes&rbrace;--&gt;B\n</pre>)

      assert Carvex.to_html!(src, plugins: [plugin]) ==
               ~s(<pre class="diagram">A{yes}--&gt;B\n</pre>)
    end
  end
end

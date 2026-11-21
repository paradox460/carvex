defmodule Carvex.SanitizeTest do
  use ExUnit.Case, async: true

  @default Carvex.Document.default_sanitize_options()

  test "removes scripts and event handlers from raw html" do
    src = "```=html\n<script>x</script><b onclick=\"y\">hi</b>\n```\n"
    html = Carvex.to_html!(src, sanitize: @default)
    assert html =~ "<b>hi</b>"
    refute html =~ "script"
    refute html =~ "onclick"
  end

  test "keeps carve footnotes, headings, and task lists" do
    src = "# T\n\nnote[^1]\n\n- [x] done\n\n[^1]: text\n"
    html = Carvex.to_html!(src, sanitize: @default)
    assert html =~ ~s(<a id="fnref1" href="#fn1" role="doc-noteref")
    assert html =~ ~s(<li id="fn1">)
    assert html =~ ~s(<a href="#fnref1" role="doc-backlink" aria-label="Back to reference")
    assert html =~ ~s(<section id="T">)
    assert html =~ ~s(<section role="doc-endnotes" aria-label="Footnotes">)
    assert html =~ ~s(<li data-task-state="x">)
    assert html =~ ~s(type="checkbox")
    assert html =~ ~s(aria-label="done")
  end

  test "sanitize options merge over defaults" do
    html = Carvex.to_html!("```=html\n<b>x</b>\n```\n", sanitize: [rm_tags: ["b"]])
    refute html =~ "<b>"
  end

  test "invalid url_relative base is an error" do
    assert {:error, %Carvex.CarveError{reason: "invalid url_relative base: " <> _}} =
             Carvex.to_html("[a](b)", sanitize: [url_relative: {:rewrite_with_base, "not a url"}])
  end

  test "safe_html" do
    assert Carvex.safe_html("<a>&</a>", sanitize: nil, escape: true) == "&lt;a&gt;&amp;&lt;/a&gt;"
    assert Carvex.safe_html("<i onclick=x>a</i>") == "<i>a</i>"
  end
end

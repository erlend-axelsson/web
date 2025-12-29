defmodule MarkdownTest do
  use ExUnit.Case
  doctest Web.Markdown

  @markdown """
  ---
  {
    "hello": "world",
    "tags": ["foo", "bar", "baz"],
    "nested": {
      "json": {
        "data": ["v","a","l","u","e"]
      }
    }
  }
  ---
  # H1 heading

  regular text

  * list0
  * list1
  * list2

  """

  test "render markdown" do
    {raw_markdown, ctx0} = Web.Markdown.extract_frontmatter(@markdown, %{})
    {markdown, ctx1} = Web.Markdown.render_markdown(raw_markdown, ctx0)

    assert ctx1 === %{
             title: "H1 heading",
             hello: "world",
             tags: ["foo", "bar", "baz"],
             intro: "regular text",
             nested: %{json: %{data: ["v", "a", "l", "u", "e"]}}
           }

    assert markdown === """
           <h2>
           H1 heading</h2>
           <p>
           regular text</p>
           <ul>
             <li>
           list0  </li>
             <li>
           list1  </li>
             <li>
           list2  </li>
           </ul>
           """
  end
end

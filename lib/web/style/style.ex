defmodule Web.Style do
  import Web.Style.Palette

  def style do
    [
      short_name: "frappe",
      long_name: "Catppuccin Frappe",
      background_color: base(),
      highlight_color: subtext_0(),
      styles: %{
        generic_heading: mantle() |> bold(),
        string: green(),
        string_escape: pink() |> bold(),
        string_regex: peach(),
        name_label: sapphire(),
        name_decorator: peach(),
        string_symbol: flamingo(),
        keyword_declaration: mauve(),
        name_class: yellow(),
        keyword_namespace: yellow(),
        string_other: text(),
        generic_emph: italic(),
        punctuation: overlay_2(),
        string_doc: italic(),
        name_tag: blue() |> bold(),
        name_builtin: red(),
        comment_preproc: overlay_2() |> noitalic(),
        comment_special: overlay_2() |> bold() |> noitalic(),
        operator_word: mauve() |> bold(),
        generic_subheading: subtext_0() |> bold(),
        name_function: blue(),
        comment_single: overlay_2(),
        name_attribute: yellow(),
        generic_strong: bold(),
        generic_traceback: blue(),
        name_exception: red() |> bold(),
        number: peach(),
        string_interpol: mauve() |> bold(),
        generic_deleted: mauve(),
        generic_error: red(),
        generic_output: text(),
        comment: overlay_2() |> italic(),
        name_entity: subtext_0() |> bold(),
        name_constant: peach(),
        name_namespace: yellow() |> bold(),
        generic_prompt: text() |> bold(),
        name: text(),
        name_builtin_pseudo: text(),
        name_variable: maroon(),
        error: border(red()),
        keyword_type: yellow() |> nobold(),
        keyword: mauve() |> bold(),
        operator: sky()
      }
    ]
  end

  defmacro make_style() do
    alias Makeup.Styles.HTML.Style
    style = Makeup.stylesheet(Style.make_style(style()))
    quote(do: unquote(style))
  end
end

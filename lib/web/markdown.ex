defmodule Web.Markdown do
  defguardp not_key(m, k) when is_map_key(m, k) === false
  defguardp header?(h?) when h? in ["h1", "h2", "h3", "h4", "h5", "h6"]

  def render_markdown(nil), do: {"", %{}}

  @dialyzer {:nowarn_function, render_markdown: 2}
  @spec render_markdown(String.t(), map()) :: {transform_html(), map()}
  def render_markdown(markdown, ctx \\ %{}) do
    ast = Earmark.as_ast!(markdown)
    {ast, info} = modify(ast, ctx)
    {transform(ast), info}
  end

  @doc """

  ## Examples
      iex> Web.Markdown.extract_frontmatter(\"""
      ...> ---
      ...> {
      ...>   "tags": ["foo", "bar", "baz"],
      ...>   "prop": 123
      ...> }
      ...> ---
      ...> # headline
      ...>
      ...> some text
      ...> \""")
      {"# headline\\n\\nsome text\\n", %{tags: ["foo", "bar", "baz"], prop: 123}}

      iex> Web.Markdown.extract_frontmatter(\"""
      ...> # headline
      ...>
      ...> some text
      ...> \""")
      {"# headline\\n\\nsome text\\n", %{}}
  """
  def extract_frontmatter(raw_markdown, ctx \\ %{}) do
    re = ~r/^---(?<front_matter>(?:.|\s)*?)---\r?\n(?<markdown>(?:.|\s)*)/

    case Regex.named_captures(re, raw_markdown, []) do
      %{"front_matter" => json, "markdown" => markdown} ->
        {markdown, parse_frontmatter(json, ctx)}

      _ ->
        {raw_markdown, ctx}
    end
  end

  def parse_frontmatter(raw_json, ctx) do
    case JSON.decode(raw_json) do
      {:ok, term = %{}} -> Map.merge(ctx, atomize(term))
      _ -> ctx
    end
  end

  defp atomize({k = <<_::binary>>, v}), do: {String.to_atom(k), atomize(v)}
  defp atomize(l) when is_list(l), do: for(i <- l, do: atomize(i))
  defp atomize(m) when is_map(m), do: for(i <- m, into: %{}, do: atomize(i))
  defp atomize(term), do: term

  @dialyzer {:nowarn_function, modify: 2}
  @spec modify(Earmark.ast(), map()) :: {Earmark.ast(), map()}
  defp modify(ast, ctx) do
    Earmark.Restructure.walk_and_modify_ast(ast, ctx, &do_restructure/2)
  end

  @opaque transform_html() :: String.t()
  @dialyzer {:nowarn_function, transform: 1}
  @spec transform(Earmark.ast()) :: transform_html()
  defp transform(ast), do: Earmark.transform(ast, escape: false)

  defp do_restructure({tag, attr, content, meta}, acc) when header?(tag) do
    acc =
      case is_map_key(acc, :title) do
        true -> acc
        false -> Map.put(acc, :title, ast_text(content))
      end

    {{normalize_header(tag), attr, content, meta}, acc}
  end

  defp do_restructure(n = {"img", attr, _content, _meta}, acc) when not_key(acc, :image) do
    case attr(attr, "src") do
      nil ->
        {n, acc}

      src ->
        alt = attr(attr, "alt", "")
        {n, Map.merge(acc, %{image: %{alt: alt, src: src}})}
    end
  end

  defp do_restructure({"p", _attr, ["!DATE " <> raw_dt], _meta}, acc) do
    acc =
      case DateTime.from_iso8601(raw_dt) do
        {:ok, dt, _} -> Map.put(acc, :last_updated, Web.Helper.dt_string(dt))
        _ -> acc
      end

    {[], acc}
  end

  defp do_restructure(n = {"p", _attr, content, _meta}, acc) when not_key(acc, :intro) do
    {n,
     case String.trim(ast_text(content)) do
       "" -> acc
       intro -> Map.put(acc, :intro, intro)
     end}
  end

  defp do_restructure({"pre", _attr, [{"code", attr, content, _}], _meta}, acc) do
    lang = downcase_attr(attr, "class")

    lexer =
      case Makeup.Registry.fetch_lexer_by_name(lang) do
        {:ok, {lexer, _opts}} -> lexer
        :error -> Makeup.Lexers.ElixirLexer
      end

    text = ast_text(content)
    code_html = Makeup.highlight(text, lexer: lexer)
    {code_html, acc}
  end

  defp do_restructure(n, acc), do: {n, acc}

  defp normalize_header("h1"), do: "h2"
  defp normalize_header(h_tag), do: h_tag

  defp ast_text({_tag, _attr, content, _meta}), do: ast_text(content)
  defp ast_text(list) when is_list(list), do: for(item <- list, into: "", do: ast_text(item))
  defp ast_text(bin = <<_::binary>>), do: bin

  defp attr(node, key, default \\ nil) do
    case Earmark.AstTools.find_att_in_node(node, key) do
      nil -> default
      attr -> attr
    end
  end

  defp downcase_attr(node, key, default \\ nil) do
    case attr(node, key, default) do
      val when is_binary(val) -> String.downcase(val)
      val -> val
    end
  end
end

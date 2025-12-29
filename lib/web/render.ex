defmodule Web.Render do
  @dialyzer {:nowarn_function, markdown_template: 1}

  require EEx
  require Web.Helper

  @external_resource Web.Helper.priv_path_macro("template/index.html.eex")
  EEx.function_from_file(:defp, :index_template, "priv/template/index.html.eex", [:assigns])

  def render_index(path_infos) do
    now = DateTime.utc_now()
    updated = Web.Helper.utc_string(now)

    assigns =
      Map.merge(
        Web.Conf.conf_opts(),
        %{
          title: "/root",
          updated: updated,
          articles: path_infos
        }
      )

    {index_template(assigns), %{last_updated: now}}
  end

  @external_resource Web.Helper.priv_path_macro("template/markdown.html.eex")
  EEx.function_from_file(:defp, :markdown_template, "priv/template/markdown.html.eex", [:assigns])
  @dialyzer {:no_return, render_markdown_html: 2}
  def render_markdown_html(markdown, ctx) do
    {markdown, ctx} = Web.Markdown.extract_frontmatter(markdown, ctx)
    {markdown, info} = Web.Markdown.render_markdown(markdown, ctx)
    info = Map.put(info, :mime, "text/html")
    conf = Web.Conf.conf_opts()

    assigns =
      conf
      |> Map.put(:markdown, markdown)
      |> Map.merge(info)

    {markdown_template(assigns), info}
  end

  @external_resource Web.Helper.priv_path_macro("template/list_item.html.eex")
  EEx.function_from_file(
    :defp,
    :list_item_template,
    "priv/template/list_item.html.eex",
    [:path, :title, :intro, :image_src, :image_alt]
  )

  def list_item({path, info}) do
    {image_src, image_alt} = image_src_alt(path, info)

    list_item_template(
      path,
      get_title(path, info),
      get_intro(info),
      image_src,
      image_alt
    )
  end

  @external_resource Web.Helper.priv_path_macro("template/archive.html.eex")
  EEx.function_from_file(
    :defp,
    :archive_template,
    "priv/template/archive.html.eex",
    [:assigns]
  )

  def render_archive(path_infos) do
    now = DateTime.utc_now()
    updated = Web.Helper.utc_string(now)

    assigns =
      Map.merge(
        Web.Conf.conf_opts(),
        %{
          title: "/archive",
          updated: updated,
          articles: path_infos,
          last_updated: now
        }
      )

    {archive_template(assigns), %{last_updated: now}}
  end

  def archive_items(items) do
    for {path, ctx_info} <- items do
      title = Map.get(ctx_info, :title, path)
      last_updated = Map.get(ctx_info, :last_updated, ~U[1970-01-01 00:00:00Z])
      tags = Map.get(ctx_info, :tags, [])
      tags = if(:sets.is_set(tags), do: :sets.to_list(tags), else: tags)
      unix_dt = DateTime.to_unix(last_updated, :second)
      {unix_dt, path, title, last_updated, tags}
    end
    |> Enum.sort(:desc)
    |> Enum.map(&archive_item/1)
  end

  @external_resource Web.Helper.priv_path_macro("template/archive_item.html.eex")
  EEx.function_from_file(
    :defp,
    :archive_item_template,
    "priv/template/archive_item.html.eex",
    [:path, :title, :last_updated, :tags]
  )

  defp archive_item({_, path, title, last_updated, tags}) do
    archive_item_template(path, title, last_updated, tags)
  end

  def process_item(object = %Web.Req.List.Object{}, bin) do
    name = Web.Helper.abs_to_rel(object.key)
    mime = MIME.from_path(object.key)

    process_item(name, mime, bin, %{
      etag: object.etag,
      size: object.size,
      last_updated: object.last_modified,
      mime: mime
    })
  end

  def process_item(name, "application/zip", bin, ctx) do
    with {:ok, file_bins} <- Web.Zip.unpack(bin) do
      for {fname, bin} <- file_bins do
        item_name = Path.join(normalize_file_name(name), fname)
        IO.inspect(fname, label: "process_item fname")
        process_item(item_name, MIME.from_path(fname), bin, ctx)
      end
    end
  end

  def process_item(name, "text/markdown", bin, ctx) do
    {html, ctx} = render_markdown_html(bin, ctx)
    IO.inspect(ctx, label: "markdown ctx")
    {:ok, {normalize_file_name(name), "text/html", html, ctx}}
  end

  def process_item(name, mime, bin, ctx) do
    {:ok, {normalize_file_name(name), mime, bin, ctx}}
  end

  defp normalize_file_name(fname) do
    fname
    |> Web.Helper.slash_prefix()
    |> String.trim_trailing(".md")
    |> String.trim_trailing(".html")
    |> String.trim_trailing(".zip")
  end

  defp get_title(path, info), do: Access.get(info, :title, Web.Helper.to_display_string(path))

  defp get_intro(info) do
    intro = info |> Access.get(:intro, "") |> String.slice(0, 197)

    case String.length(intro) do
      197 -> intro <> "..."
      _ -> intro
    end
  end

  defp image_src_alt(base_path, %{image: %{src: src, alt: alt}}) do
    base_path = Path.dirname(base_path)

    src =
      case path_type(src) do
        :directory_relative -> Path.join(base_path, src)
        _ -> src
      end

    {src, alt}
  end

  defp image_src_alt(_, _), do: {nil, nil}

  defp path_type("http" <> _), do: :absolute
  defp path_type("/" <> _), do: :root_relative
  defp path_type(_), do: :directory_relative
end

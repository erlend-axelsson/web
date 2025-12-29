defmodule Web.Helper do
  defmacro html_type(conn) do
    quote(do: Plug.Conn.put_resp_content_type(unquote(conn), "text/html"))
  end

  defmacro css_type(conn) do
    quote(do: Plug.Conn.put_resp_content_type(unquote(conn), "text/css"))
  end

  defmacro svg_type(conn) do
    quote(do: Plug.Conn.put_resp_content_type(unquote(conn), "image/svg+xml"))
  end

  defmacro highlight_style(style \\ :default_style) do
    quote(do: unquote(Makeup.stylesheet(style)))
  end

  defmacro slash_prefix_m(bin) do
    quote do
      case unquote(bin) do
        "/" <> _val -> unquote(bin)
        _val -> "/" <> unquote(bin)
      end
    end
  end

  def slash_prefix(<<"/", _::binary>> = str), do: str
  def slash_prefix(str), do: "/" <> str

  def to_display_string(str) do
    str
    |> Path.basename()
    |> Path.rootname()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  def dt_string(date_time, truncate \\ :second) do
    date_time |> DateTime.truncate(truncate) |> DateTime.to_iso8601()
  end

  def utc_string(datetime, truncate \\ :second) do
    datetime |> DateTime.truncate(truncate) |> DateTime.to_iso8601()
  end

  defmacro utc_string_m(truncate \\ :second) do
    quote do
      unquote(DateTime.utc_now() |> DateTime.truncate(truncate) |> DateTime.to_iso8601())
    end
  end

  def merge(collections), do: merge(collections, %{})
  defp merge([head | rest], acc), do: merge(rest, Map.merge(acc, Map.new(head)))
  defp merge([], acc), do: acc

  def ensure_end_with("", postfix), do: postfix

  def ensure_end_with(string, postfix) when byte_size(string) < byte_size(postfix),
    do: string <> postfix

  def ensure_end_with(string, postfix) do
    string_size = byte_size(string)
    postfix_size = byte_size(postfix)
    string_end = :binary.part(string, string_size - postfix_size, postfix_size)

    case string_end === postfix do
      true -> string
      false -> string <> postfix
    end
  end

  def priv_dir(), do: Application.app_dir(:web, ["priv"])
  def priv_path(path), do: Path.join(priv_dir(), path)
  defmacro priv_path_macro(path), do: quote(do: unquote(priv_path(path)))

  def abs_to_rel(path), do: Path.relative_to(path, priv_dir())
  def abs_to_rel(path, priv_rel), do: Path.relative_to(path, Path.join(priv_dir(), priv_rel))
  def abs_to_priv_rel(path), do: Path.relative_to(path, priv_dir())
  def abs_to_priv_rel(path, priv_rel), do: Path.relative_to(path, Path.join(priv_dir(), priv_rel))
  def file(path), do: File.read!(priv_path(path))
  defmacro embed_file(path), do: quote(do: unquote(file(path)))

  def priv_glob(glob) do
    Path.wildcard(Path.join(priv_dir(), glob))
  end
end

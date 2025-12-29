defmodule Web.NotFound do
  require Web.Helper
  require EEx
  use Plug.Builder
  @external_resource Web.Helper.priv_path("template/404.html.eex")
  EEx.function_from_file(:defp, :render, Web.Helper.priv_path("template/404.html.eex"), [
    :assigns
  ])

  plug(:not_found)

  def not_found(%Plug.Conn{} = conn, _opts) do
    key = conn.request_path
    message = "#{key} is not found"
    assigns = Map.merge(Web.Conf.conf_opts(), %{key: key, message: message})
    send_resp(Web.Helper.html_type(conn), 404, render(assigns))
  end
end

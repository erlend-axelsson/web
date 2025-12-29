defmodule Web.Routes do
  require Web.Helper
  require Web.Render
  require Web.Style
  alias Web.Helper
  alias Plug.Router
  alias Plug.Conn
  use Router

  plug(Plug.Static,
    at: "/public",
    from: {:web, "priv/public/"}
  )

  plug(:match)
  plug(:dispatch)

  @external_resource Helper.priv_path("static/favicon.svg")
  Router.get "/favicon.svg" do
    Conn.send_file(Helper.svg_type(conn), 200, Helper.priv_path("static/favicon.svg"))
  end

  @external_resource Helper.priv_path("static/style.css")
  Router.get "/style.css" do
    Conn.send_file(Helper.css_type(conn), 200, Helper.priv_path("static/style.css"))
  end

  Router.get "/highlight.css" do
    Conn.send_resp(Helper.css_type(conn), 200, Web.Style.make_style())
  end

  Router.match(_, to: Web.ETS.Route)
end

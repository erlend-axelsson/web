defmodule Web.ETS.Route do
  require Web.ETS.Gen
  @behaviour Plug

  def init(opts), do: opts

  def call(%Plug.Conn{} = conn, opts) do
    import Plug.Conn, only: [put_resp_content_type: 2, send_resp: 3]

    case :ets.lookup(tid(), conn.request_path) do
      [object] -> send_response(conn, object)
      [] -> Web.NotFound.call(conn, opts)
    end
  end

  defp tid(), do: :persistent_term.get({:ets_route, :tid})

  defp send_response(
         conn,
         Web.ETS.Gen.object(
           mime: mime,
           etag: etag,
           last_updated: last_updated,
           content: content
         )
       ) do
    import Plug.Conn, only: [put_resp_header: 3, put_resp_content_type: 2, send_resp: 3]
    import Req.Utils, only: [format_http_date: 1]

    conn
    |> put_resp_content_type(mime)
    |> put_resp_header("Last-Modified", format_http_date(last_updated))
    |> put_resp_header("ETag", etag)
    |> send_resp(200, content)
  end
end

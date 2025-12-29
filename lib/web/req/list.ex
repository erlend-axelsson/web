defmodule Web.Req.List.Object do
  defstruct [:key, :etag, :last_modified, :size]

  @type t() :: %__MODULE__{
          key: String.t(),
          etag: String.t(),
          last_modified: DateTime.t(),
          size: integer()
        }
end

defmodule Web.Req.List do
  defstruct truncated: false,
            cont_token: nil,
            objects: []

  @type t() :: %__MODULE__{
          truncated: boolean(),
          cont_token: term(),
          objects: [Web.Req.List.Object.t()]
        }
  def get(prefix \\ nil, cont_token \\ nil, acc \\ %__MODULE__{}) do
    prefix = prefix(prefix)
    cont_token = cont_token(cont_token)

    url = "/?list-type=2#{cont_token}#{prefix}"

    with {:ok, resp} <- Req.get(Web.Req.Base.base_req(), url: url),
         {:ok, %__MODULE__{} = list_response} <- parse_xml(resp.body) do
      case list_response.truncated do
        true -> get(prefix, list_response.cont_token, merge_stuct(acc, list_response))
        false -> {:ok, merge_stuct(acc, list_response)}
      end
    end
  end

  @spec parse_xml(iodata()) :: {:ok, t()} | {:error, any()}
  def parse_xml(body) do
    import SweetXml

    try do
      parsed =
        body
        |> parse(quiet: true, dtd: :none)
        |> xpath(
          ~x".",
          truncated: ~x"IsTruncated/text()"s |> transform_by(&bool_val/1),
          cont_token: ~x"ContinuationToken/text()"s |> transform_by(&empty_as_nil/1),
          objects: [
            ~x"Contents"l,
            key: ~x"Key/text()"s,
            etag: ~x"ETag/text()"s,
            size: ~x"Size/text()"s |> transform_by(&int_val/1),
            last_modified: ~x"LastModified/text()"s |> transform_by(&datetime_val/1)
          ]
        )

      # TODO can I use transform_by on list elements directly?
      objects = for raw_object <- parsed.objects, do: struct(Web.Req.List.Object, raw_object)

      {:ok, struct(__MODULE__, %{parsed | objects: objects})}
    catch
      :exit, e -> {:error, e}
    end
  end

  defp merge_stuct(acc = %__MODULE__{}, list_response = %__MODULE__{}) do
    %{list_response | objects: list_response.objects ++ acc.objects}
  end

  defp cont_token(nil), do: ""
  defp cont_token(<<"&continuation-token=", _::binary>> = cont_token), do: cont_token
  defp cont_token(cont_token), do: "&continuation-token=#{URI.encode(cont_token)}"

  defp prefix(nil), do: ""
  defp prefix(<<"&prefix=", _::binary>> = prefix), do: prefix
  defp prefix(prefix), do: "&prefix=#{URI.encode(prefix)}"

  defp bool_val("true"), do: true
  defp bool_val("false"), do: false
  defp empty_as_nil(""), do: nil
  defp empty_as_nil(s), do: s

  defp int_val(num) do
    case(Integer.parse(num)) do
      :error -> 0
      {int, _} -> int
    end
  end

  defp datetime_val(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> ~U[1970-01-01 00:00:00Z]
    end
  end
end

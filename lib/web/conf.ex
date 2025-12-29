defmodule Web.Conf do
  defguardp key_value?(kv?) when is_map(kv?) or is_list(kv?)

  @type s3_options() :: %{
          base_url: String.t(),
          access_key_id: String.t(),
          secret_access_key: String.t(),
          service: String.t(),
          region: String.t()
        }

  @spec s3_opts() :: s3_options()
  def s3_opts() do
    with nil <- :persistent_term.get({:conf, :s3}, nil) do
      env =
        Application.get_env(:web, :s3_settings)
        |> Map.new()

      :persistent_term.put({:conf, :s3}, env)
      env
    end
  end

  def conf_opts() do
    with nil <- :persistent_term.get({:conf, :web}, nil) do
      env = flatten_env([], Application.get_env(:web, :context))
      :persistent_term.put({:conf, :web}, env)
      env
    end
  end

  defp flatten_env(key_path, container) do
    container
    |> Enum.flat_map(fn
      {key, value} when key_value?(value) ->
        flatten_env([key | key_path], value)

      {key, value} ->
        [{atom_key(key_path, key), value}]
    end)
    |> Map.new()
  end

  defp atom_key(key_path, tail) do
    key_path
    |> Enum.reverse([tail])
    |> Enum.map_join("_", &to_string/1)
    |> String.to_atom()
  end
end

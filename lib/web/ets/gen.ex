defmodule Web.ETS.Gen do
  require Logger
  @update_delay :timer.hours(1)

  defstruct [:tid, :prefix]
  require Record

  Record.defrecord(:object,
    name: :_,
    mime: :_,
    etag: :_,
    last_updated: :_,
    tags: :_,
    content: :_,
    info: :_
  )

  # {:object, name, mime, etag, last_updated, tags, content, info}
  @type t() :: %__MODULE__{tid: :ets.tid(), prefix: String.t()}
  @type object_record() ::
          record(:object,
            name: String.t() | atom(),
            mime: String.t() | atom(),
            etag: any(),
            last_updated: String.t() | atom(),
            tags: :sets.set() | atom(),
            content: iodata() | atom(),
            info: map() | atom()
          )

  use GenServer

  def fetch_from_s3(prefix \\ nil)

  def fetch_from_s3(nil) do
    GenServer.cast(__MODULE__, :get_objects)
  end

  def fetch_from_s3(prefix) do
    GenServer.cast(__MODULE__, {:get_objects, prefix})
  end

  def child_spec(prefix), do: %{id: __MODULE__, start: {__MODULE__, :start_link, [prefix]}}
  def start_link(prefix), do: GenServer.start_link(__MODULE__, prefix, name: __MODULE__)

  def init(prefix) do
    state = %__MODULE__{tid: :ets.new(__MODULE__, [:named_table, keypos: 2]), prefix: prefix}
    {:ok, state, {:continue, :init}}
  end

  def handle_call(_req, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(req, state), do: handle_common(req, state)
  def handle_info(req, state), do: handle_common(req, state)

  def handle_continue(req, state), do: handle_common(req, state)

  defp handle_common(:init, state) do
    :persistent_term.put({:ets_route, :tid}, state.tid)
    {:noreply, state, {:continue, :get_objects}}
  end

  defp handle_common(:get_objects, state), do: handle_common({:get_objects, state.prefix}, state)

  defp handle_common({:get_objects, prefix}, state) do
    alias Web.Req.List

    with {:ok, %List{objects: objects}} <- List.get(prefix) do
      delete_items(objects, state.tid)
      objects_to_fetch = objects_to_fetch(objects, state.tid)
      {:noreply, state, {:continue, {:download_object, objects_to_fetch}}}
    else
      _ -> {:noreply, state, {:continue, :generate_index}}
    end
  end

  defp handle_common({:download_object, []}, state) do
    {:noreply, state, {:continue, :generate_index}}
  end

  defp handle_common({:download_object, [head | objects_to_fetch]}, state) do
    with {:ok, %Req.Response{status: 200, body: body}} <- Web.Req.Object.get(head.key) do
      process_res =
        Web.Render.process_item(head, body) |> List.wrap() |> List.flatten()

      process_res =
        for {:ok, {name, mime, content, ctx}} <- process_res do
          object(
            name: name,
            mime: mime,
            etag: ctx.etag,
            last_updated: Map.get(ctx, :last_updated, ~U[1970-01-01 00:00:00Z]),
            tags: Map.get(ctx, :tags, []) |> :sets.from_list(),
            content: content,
            info: ctx
          )
        end

      :ets.insert(state.tid, process_res)
    end

    {:noreply, state, {:continue, {:download_object, objects_to_fetch}}}
  end

  defp handle_common(:generate_index, state) do
    match_head = object(name: :"$1", mime: "text/html", last_updated: :"$2", info: :"$3")
    match_spec = [{match_head, [{:"=/=", :"$1", "/"}], [{{:"$1", :"$2", :"$3"}}]}]
    select_res = :ets.select(state.tid, match_spec)

    path_infos =
      for {path, _, info} <- Enum.sort(select_res, &sort_by_newest/2) do
        {path, info}
      end

    {content, ctx} = Web.Render.render_index(path_infos)

    root_object =
      object(
        name: "/",
        mime: "text/html",
        etag: hash(content),
        last_updated: Map.get(ctx, :last_updated, ~U[1970-01-01 00:00:00Z]),
        tags: Map.get(ctx, :tags, []) |> :sets.from_list(),
        content: content,
        info: ctx
      )

    :ets.insert(state.tid, root_object)
    {:noreply, state, {:continue, {:generate_archive, path_infos}}}
  end

  defp handle_common({:generate_archive, path_infos}, state) do
    {content, ctx} = Web.Render.render_archive(path_infos)

    archive_object =
      object(
        name: "/archive",
        mime: "text/html",
        etag: hash(content),
        last_updated: Map.get(ctx, :last_updated, ~U[1970-01-01 00:00:00Z]),
        tags: Map.get(ctx, :tags, []) |> :sets.from_list(),
        content: content,
        info: ctx
      )

    :ets.insert(state.tid, archive_object)
    Process.send_after(self(), {:get_objects, state.prefix}, @update_delay)
    {:noreply, state}
  end

  def has_etag?(etag, tid) do
    match_spec = [{object(etag: :"$1"), [{:"=:=", :"$1", etag}], [true]}]
    # files from zip archive share etag hence count > 0 instead of count === 1
    :ets.select_count(tid, match_spec) > 0
  end

  defp objects_to_fetch(objects, tid, acc \\ [])
  defp objects_to_fetch([], _tid, acc), do: acc

  defp objects_to_fetch([hd | tl], tid, acc) do
    case hd.size > 0 and not has_etag?(hd.etag, tid) do
      true -> objects_to_fetch(tl, tid, [hd | acc])
      false -> objects_to_fetch(tl, tid, acc)
    end
  end

  defp delete_items(objects, tid) do
    remote_names =
      for object(name: name) <- objects,
          do: Web.Helper.slash_prefix(Path.rootname(name))

    for [cache_name] <- :ets.match(tid, object(name: :"$1")) do
      case delete_predicate(remote_names, cache_name) do
        true ->
          :ok

        false ->
          Logger.info("REMOVE #{cache_name} from cache")
          :ets.delete(tid, cache_name)
      end
    end
  end

  defp delete_predicate(_, "/"), do: true
  defp delete_predicate([], _), do: false

  defp delete_predicate([remote_hd | remote_tl], cache_name) do
    case String.starts_with?(cache_name, remote_hd) do
      true -> true
      false -> delete_predicate(remote_tl, cache_name)
    end
  end

  defp sort_by_newest({_, updated0, _}, {_, updated1, _}),
    do: DateTime.after?(updated0, updated1)

  defp hash(term) do
    term |> :erlang.phash2() |> :erlang.integer_to_binary()
  end
end

defmodule Web.Zip do
  def pack_priv(rel_path, file_bins) do
    pack(Web.Helper.priv_path(rel_path), file_bins)
  end

  def pack(path, file_bins) do
    :zip.create(~c"#{path}", for({fname, bin} <- file_bins, do: {~c"#{fname}", bin}))
  end

  def unpack(file_bin_list) when is_list(file_bin_list) do
    file_bin_list =
      for {fname, bin} <- file_bin_list, filter_zip_item(fname, bin) do
        {:erlang.list_to_binary(fname), bin}
      end

    {:ok, file_bin_list}
  end

  def unpack(content) when is_binary(content) do
    with {:ok, file_bin_list} <- :zip.extract(content, [:memory]), do: unpack(file_bin_list)
  end

  defp filter_zip_item(fname, bin) do
    byte_size(bin) > 0 and not List.starts_with?(fname, ~c"__MACOSX")
  end

  def unpack_priv(rel_path) do
    with {:ok, bin} <- File.read(Web.Helper.priv_path(rel_path)), do: unpack(bin)
  end

  def create(name, file_list, opts \\ []) do
    dir_name = Path.rootname(name)
    name = name |> :erlang.binary_to_list() |> IO.inspect()

    file_list =
      for {fname, bin} <- file_list do
        rel_name = Path.relative_to(fname, dir_name)
        {:erlang.binary_to_list(rel_name), bin}
      end

    :zip.create(name, file_list, opts)
  end

  def pack_priv_files(dir) do
    priv_path = Web.Helper.priv_path(dir)
    pack_files(priv_path)
  end

  def pack_files(dir) do
    archive_name = dir <> ".zip"
    fnames = Path.wildcard(Path.join(dir, "**/*.*"))

    with {:ok, file_list} <- Enum.reduce_while(fnames, {:ok, []}, &read_reducer/2) do
      create(archive_name, file_list)
      :ok
    end
  end

  defp read_reducer(fname, {:ok, acc}) do
    case File.read(fname) do
      {:ok, bin} -> {:cont, {:ok, [{fname, bin} | acc]}}
      {:error, posix} -> {:halt, {:error, posix}}
    end
  end

  def pack_files(file_paths = [_ | _], out_path) do
    longest_prefix = :binary.longest_common_prefix(file_paths)

    files =
      for p <- file_paths do
        fname = ~c"#{String.slice(p, longest_prefix, byte_size(p) - longest_prefix)}"
        {fname, File.read!(p)}
      end

    :zip.create(~c"#{out_path}", files)
  end
end

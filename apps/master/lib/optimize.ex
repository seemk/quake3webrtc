defmodule Master.Optimize do
  require Logger

  def optimize(pak_files) do
    {paks, other} =
      pak_files
      |> Enum.map(fn p -> {p, File.read(p)} end)
      |> Enum.filter(fn {path, s} ->
        case s do
          {:ok, _content} ->
            true

          {:error, e} ->
            Logger.info("can't read #{path}: '#{inspect(e)}', skipping")
            false
        end
      end)
      |> Enum.map(fn {path, {:ok, content}} ->
        case :zip.unzip(content, [:memory]) do
          {:ok, files} ->
            {Path.basename(path), files}

          {:error, e} ->
            Logger.info("failed to unzip #{path}: #{inspect(e)}")
            nil
        end
      end)
      |> Enum.filter(fn v -> v != nil end)
      |> Enum.partition(fn {name, _} ->
        String.starts_with?(name, "pak")
      end)

    paks
    |> Enum.map(fn p -> get_pak_dir(p, "maps") end)
    |> Enum.map(fn {p, assets} ->
      Enum.reduce(
        assets,
        %{
          :bsps => %{}
        },
        fn {path, content}, acc ->
          ext = Path.extname(path) |> String.downcase()

          case ext do
            ".bsp" ->
              bsp = parse_bsp(content)
              put_in(acc, [:bsps, to_string(path)], bsp)

            _ ->
              acc
          end
        end
      )
    end)

    # |> IO.inspect()
  end

  defp get_pak_dir({pk_name, assets}, dir) do
    # IO.inspect(assets)

    filtered =
      Enum.filter(assets, fn {path, _} ->
        Path.dirname(path) == dir
      end)

    {pk_name, filtered}
  end

  defp parse_bsp(
         <<_identifier::binary-size(4), _version::little-integer-32,
           entities_offset::little-integer-32, entities_size::little-integer-32,
           tex_offset::little-integer-32, tex_size::little-integer-32, _::binary-size(80),
           fogs_offset::little-integer-32, fogs_size::little-integer-32, _::binary>> = bsp
       ) do
    %{
      :shaders =>
        (parse_shaders(binary_part(bsp, tex_offset, tex_size)) ++
           parse_shaders(binary_part(bsp, fogs_offset, fogs_size)))
        |> Enum.uniq(),
      :entities =>
        Regex.split(
          ~r/\{([^{}]*)\}/,
          binary_part(bsp, entities_offset, entities_size),
          include_captures: true,
          trim: true
        )
        |> Enum.filter(fn s -> s != "\n" end)
        |> Enum.map(fn e -> parse_entity(e) end)
    }
  end

  def parse_entity(s) do
    Regex.scan(~r/"(.+)" "(.+)"/, s)
    |> Enum.reduce(%{}, fn [_, k, v], acc ->
      Map.put(acc, k, v)
    end)
  end

  def parse_shaders(binary) do
    parse_shaders(binary, [])
  end

  defp parse_shaders(
         <<name::binary-size(64), _flags::little-integer-32, _contents::little-integer-32,
           rest::binary>>,
         textures
       ) do
    parse_shaders(rest, [String.replace(name, "\0", "") | textures])
  end

  defp parse_shaders(<<>>, textures) do
    textures
  end
end

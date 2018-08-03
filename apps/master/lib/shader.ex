defmodule Shader do
  def parse(s) do
    s = Regex.replace(~r/\/\*.*\*\//s, s, "")

    Regex.replace(~r/\/\/.*\s*/, s, "")
    |> String.split()
    |> IO.inspect()
    |> parse_shader

    # |> Enum.reduce_while(%{:state => :begin}, &do_parse/2)
  end

  defp parse_shader(tokens) do
    do_parse(tokens, :begin, %{})
  end

  defp do_parse(tokens, state, ctx) do
    case state do
      :begin ->
        case tokens do
          ["{" | _] ->
            {:error, ctx}

          [shader, "{" | rest] ->
            do_parse(
              rest,
              {:shader, shader},
              put_in(ctx, [shader], %{:params => %{}, :stages => []})
            )
          [] ->
          {:ok, ctx}
        end

      {:shader, shader} ->
        case tokens do
          ["{" | rest] ->
            do_parse(rest, {:stage, shader, %{}}, ctx)
          ["}" | rest] ->
            do_parse(rest, :begin, ctx)
          [_ | rest] ->
            do_parse(rest, {:shader, shader}, ctx)
        end

      {:stage, shader, stage} ->
        case tokens do
          ["map" = key, path | rest] ->
            do_parse(rest, {:stage, shader, Map.put(stage, key, path)}, ctx)
          ["clampmap" = key, path | rest] ->
            do_parse(rest, {:stage, shader, Map.put(stage, key, path)}, ctx)
          ["animmap" = key, _ | rest] ->
            paths = Enum.take_while(rest, fn v ->
              Regex.match?(~r/.+\.(tga|jpg)/, v)
            end)
            rest = Enum.drop(rest, Enum.count(paths))
            do_parse(rest, {:stage, shader, Map.put(stage, key, paths)}, ctx)

          ["}" | rest] ->
            do_parse(
              rest,
              {:shader, shader},
              put_in(ctx, [shader, :stages], [stage | ctx[shader][:stages]])
            )

          [_ | rest] ->
            do_parse(rest, {:stage, shader, stage}, ctx)
        end

      _ ->
        {:ok, ctx}
    end
  end


end

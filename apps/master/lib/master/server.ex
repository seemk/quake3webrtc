defmodule Master.Server do
  use GenServer

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(%{:port => port}) do
    Logger.info("open port #{port}")
    {:ok, socket} = :gen_udp.open(port, [:binary])

    {:ok, %{:socket => socket}}
  end

  def handle_info(
        {:udp, socket, ip, port, <<_::binary-size(4), "heartbeat", _::binary>> = hb},
        state
      ) do
    :gen_udp.send(socket, ip, port, format_oob("getinfo #{gen_challenge(16)}")) 
    {:noreply, state}
  end

  def handle_info(
        {:udp, socket, ip, port, <<_::binary-size(4), "infoResponse\n", arg_string::binary>> = hb},
        state
      ) do

    args = String.split(arg_string, "\\", trim: true)
    IO.inspect args
    {:noreply, state}
  end

  def handle_info({:udp, _socket, _ip, _port, data}, state) do
    Logger.info("recv data")
    IO.inspect data
    {:noreply, state}
  end

  defp gen_challenge(n) do
    chars = "1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    |> String.split("")

    1..n
    |> Enum.reduce([], fn (_, acc) -> [Enum.random(chars) | acc] end)
    |> Enum.join("")
  end

  defp format_oob(msg) do
    <<255, 255, 255, 255, msg::binary, 0>>
  end

end

defmodule Jellyfish.WS do
  @moduledoc false

  use WebSockex

  alias Jellyfish.PeerMessage

  def start_link(url) do
    WebSockex.start_link(url, __MODULE__, %{caller: self()})
  end

  def send_frame(ws, msg) do
    WebSockex.send_frame(ws, {:binary, PeerMessage.encode(msg)})
  end

  @impl true
  def handle_frame({:binary, msg}, state) do
    msg = PeerMessage.decode(msg)
    send(state.caller, msg)
    {:ok, state}
  end

  @impl true
  def handle_disconnect(conn_status, state) do
    send(state.caller, {:disconnected, conn_status.reason})
    {:ok, state}
  end
end

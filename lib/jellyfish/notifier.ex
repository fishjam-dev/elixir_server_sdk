defmodule Jellyfish.Notifier do
  @moduledoc """
  Module defining a process responsible for establishing
  WebSocket connection and receiving notifications form Jellyfish server.

  ```
  iex> {:ok, pid} = Jellyfish.Notifier.start(server_address: "address-of-jellyfish-server.com", server_api_token: "your-jellyfish-token")
  {:ok, #PID<0.301.0>}

  # here add a room and a peer using functions from `Jellyfish.Room` module
  # you should receive a notification after the peer established connection

  iex> flush()
  {:jellyfish,
   {:peer_connected, "21604fbe-8ac8-44e6-8474-98b5f50f1863",
    "ae07f94e-0887-44c3-81d5-bfa9eac96252"}}
  :ok
  ```
  """

  use WebSockex

  require Logger

  alias Jellyfish.{Client, Utils}
  alias Jellyfish.Exception.StructureError
  alias Jellyfish.Server.ControlMessage

  alias Jellyfish.Server.ControlMessage.{
    Authenticated,
    AuthRequest,
    ComponentCrashed,
    PeerConnected,
    PeerCrashed,
    PeerDisconnected,
    RoomCrashed
  }

  @auth_timeout 2000

  @doc """
  Starts the Notifier process and connects to Jellyfish.

  Acts like `start/1` but links to the calling process.

  See `start/1` for more information.
  """
  @spec start_link(Client.connection_options()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    connect(:start_link, opts)
  end

  @doc """
  Starts the Notifier process and connects to Jellyfish.

  Received notifications are send to the calling process in
  a form of `{:jellyfish, msg}`, where `msg` is
  `type` or `{type, room_id}` or `{type, room_id, (peer/component)_id}`.
  Refer to [Jellyfish docs](https://jellyfish-dev.github.io/jellyfish-docs/) to learn more about server notifications.

  For information about options, see `t:Jellyfish.Client.connection_options/0`.
  """
  @spec start(Client.connection_options()) :: {:ok, pid()} | {:error, term()}
  def start(opts \\ []) do
    connect(:start, opts)
  end

  @impl true
  def handle_frame({:binary, msg}, state) do
    with decoded_msg <- ControlMessage.decode(msg),
         {:ok, notification} <- decode_notification(decoded_msg) do
      # notification will be either {type, room_id, peer_id/component_id},
      # {type, room_id} or just type
      send(state.receiver_pid, {:jellyfish, notification})
    else
      _other -> raise StructureError
    end

    {:ok, state}
  end

  @impl true
  def handle_cast(_msg, state) do
    # ignore incoming messages
    {:ok, state}
  end

  @impl true
  def terminate({:remote, 1000, "invalid token"}, state) do
    send(state.receiver_pid, {:jellyfish, :invalid_token})
  end

  @impl true
  def terminate(_reason, state) do
    send(state.receiver_pid, {:jellyfish, :disconnected})
  end

  defp connect(fun, opts) do
    {address, api_token, secure?} = Utils.get_options_or_defaults(opts)
    address = if secure?, do: "wss://#{address}", else: "ws://#{address}"
    state = %{receiver_pid: self()}

    auth_msg =
      %ControlMessage{content: {:authRequest, %AuthRequest{token: api_token}}}
      |> ControlMessage.encode()

    with {:ok, pid} <-
           apply(WebSockex, fun, ["#{address}/socket/server/websocket", __MODULE__, state]),
         :ok <- WebSockex.send_frame(pid, {:binary, auth_msg}) do
      receive do
        {:jellyfish, :authenticated} ->
          {:ok, pid}

        {:jellyfish, :invalid_token} ->
          {:error, :invalid_token}
      after
        @auth_timeout ->
          Process.exit(pid, :normal)
          {:error, :authentication_timeout}
      end
    else
      {:error, _reason} = error -> error
    end
  end

  defp decode_notification(%ControlMessage{
         content: {_type, %PeerDisconnected{room_id: room_id, peer_id: id}}
       }) do
    {:ok, {:peer_disconnected, room_id, id}}
  end

  defp decode_notification(%ControlMessage{
         content: {_type, %PeerConnected{room_id: room_id, peer_id: id}}
       }) do
    {:ok, {:peer_connected, room_id, id}}
  end

  defp decode_notification(%ControlMessage{
         content: {_type, %PeerCrashed{room_id: room_id, peer_id: id}}
       }) do
    {:ok, {:peer_crashed, room_id, id}}
  end

  defp decode_notification(%ControlMessage{
         content: {_type, %ComponentCrashed{room_id: room_id, component_id: id}}
       }) do
    {:ok, {:component_crashed, room_id, id}}
  end

  defp decode_notification(%ControlMessage{content: {_type, %RoomCrashed{room_id: room_id}}}) do
    {:ok, {:room_crashed, room_id}}
  end

  defp decode_notification(%ControlMessage{content: {_type, %Authenticated{}}}) do
    {:ok, :authenticated}
  end

  defp decode_notification(_other), do: {:error, :invalid_type}
end

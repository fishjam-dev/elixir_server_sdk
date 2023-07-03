defmodule Jellyfish.Notifier do
  @moduledoc """
  Module defining a process responsible for establishing
  WebSocket connection and receiving notifications form Jellyfish server.

  ```
  iex> {:ok, notifier} = Jellyfish.Notifier.start(server_address: "localhost:5002", server_api_token: "your-jellyfish-token")
  {:ok, #PID<0.301.0>}
  iex> {:ok, _rooms} = Jellyfish.Notifier.subscribe(notifier, :all)

  # here add a room and a peer using functions from `Jellyfish.Room` module
  # you should receive a notification after the peer established connection

  iex> flush()
  {:jellyfish, %Jellyfish.Notification.PeerConnected{
    room_id: "21604fbe-8ac8-44e6-8474-98b5f50f1863",
    peer_id: "ae07f94e-0887-44c3-81d5-bfa9eac96252"
  }}
  :ok
  ```
  """

  use WebSockex

  alias Jellyfish.{Client, Room, Utils}
  alias Jellyfish.{Notification, ServerMessage}

  alias Jellyfish.ServerMessage.{
    Authenticated,
    AuthRequest,
    RoomNotFound,
    RoomsState,
    RoomState,
    RoomStateRequest
  }

  @auth_timeout 2000
  @subscribe_timeout 5000

  @typedoc """
  The reference to the `Notifier` process.
  """
  @type notifier() :: GenServer.server()

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

  To learn how to receive notifications, see `subscribe/2`.

  For information about options, see `t:Jellyfish.Client.connection_options/0`.
  """
  @spec start(Client.connection_options()) :: {:ok, pid()} | {:error, term()}
  def start(opts \\ []) do
    connect(:start, opts)
  end

  @doc """
  Subscribes the process to receive server notifications about room with `room_id` and returns
  current state of the room.

  If `:all` is passed in place of `room_id`, notifications about all of the rooms will be sent and
  list of all of the room's states is returned.

  Notifications are sent to the process in a form of `{:jellyfish, msg}`,
  where `msg` is one of structs defined under "Notifications" section in the docs,
  for example `{:jellyfish, %Jellyfish.Notification.RoomCrashed{room_id: "some_id"}}`.
  """
  @spec subscribe(notifier(), Room.id() | :all) :: {:ok, Room.t() | [Room.t()]} | {:error, atom()}
  def subscribe(notifier, room_id) do
    WebSockex.cast(notifier, {:subscribe, self(), room_id})

    receive do
      {:jellyfish, {:subscribe_answer, answer}} -> answer
    after
      @subscribe_timeout -> {:error, :timeout}
    end
  end

  @impl true
  def handle_frame({:binary, msg}, state) do
    %ServerMessage{content: {_type, notification}} = ServerMessage.decode(msg)
    state = handle_notification(notification, state)

    {:ok, state}
  end

  @impl true
  def handle_cast({:subscribe, pid, room_id}, state) do
    # we use simple FIFO queue to keep track of different
    # processes wanting to subscribe to the same room's notifications
    # is assumes that the WebSocket ensures transport order as well as
    # the Jellyfish ensures processing order
    state =
      update_in(state.pending_subscriptions[room_id], fn
        nil -> [pid]
        pids -> [pid | pids]
      end)

    room_request =
      case room_id do
        :all -> {:option, :ALL}
        id -> {:id, id}
      end

    msg =
      %ServerMessage{content: {:room_state_request, %RoomStateRequest{content: room_request}}}
      |> ServerMessage.encode()

    {:reply, {:binary, msg}, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    state =
      Map.update!(state, :subscriptions, fn subs ->
        Map.new(subs, fn {id, pids} -> {id, MapSet.delete(pids, pid)} end)
      end)

    {:ok, state}
  end

  @impl true
  def terminate({:remote, 1000, "invalid token"}, state) do
    send(state.caller_pid, {:jellyfish, :invalid_token})
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end

  defp connect(fun, opts) do
    {address, api_token, secure?} = Utils.get_options_or_defaults(opts)
    address = if secure?, do: "wss://#{address}", else: "ws://#{address}"

    state = %{
      caller_pid: self(),
      subscriptions: %{all: MapSet.new()},
      pending_subscriptions: %{}
    }

    auth_msg =
      %ServerMessage{content: {:auth_request, %AuthRequest{token: api_token}}}
      |> ServerMessage.encode()

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
      {:error, _reason} = error ->
        error
    end
  end

  defp handle_notification(%Authenticated{}, state) do
    send(state.caller_pid, {:jellyfish, :authenticated})
    state
  end

  defp handle_notification(%RoomNotFound{id: id}, state) do
    {pid, pids} = List.pop_at(state.pending_subscriptions[id], -1)
    state = put_in(state.pending_subscriptions[id], pids)

    send(pid, {:jellyfish, {:subscribe_answer, {:error, :room_not_found}}})
    state
  end

  defp handle_notification(%mod{} = room, state) when mod in [RoomState, RoomsState] do
    {room_id, room} =
      case mod do
        RoomState -> {room.id, Room.from_proto(room)}
        RoomsState -> {:all, Enum.map(room.rooms, &Room.from_proto/1)}
      end

    {pid, pids} = List.pop_at(state.pending_subscriptions[room_id], -1)
    state = put_in(state.pending_subscriptions[room_id], pids)

    Process.monitor(pid)

    state =
      update_in(state.subscriptions[room_id], fn
        nil -> MapSet.new([pid])
        set -> MapSet.put(set, pid)
      end)

    send(pid, {:jellyfish, {:subscribe_answer, {:ok, room}}})
    state
  end

  defp handle_notification(%{room_id: room_id} = message, state) do
    state.subscriptions
    |> Map.take([:all, room_id])
    |> Map.values()
    |> Enum.reduce(fn pids, acc -> MapSet.union(pids, acc) end)
    |> Enum.each(&send(&1, {:jellyfish, Notification.to_notification(message)}))

    state
  end
end

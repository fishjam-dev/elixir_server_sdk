defmodule Jellyfish.Notifier do
  @moduledoc """
  Module defining a process responsible for establishing
  WebSocket connection and receiving notifications form Jellyfish server.

  Define the connection configuration
  ``` config.exs
  config :jellyfish_server_sdk,
    server_address: "localhost:5002",
    server_api_token: "your-jellyfish-token",
    secure?: true
  ```

  Optionally, you can provide it using the options:
  ```
  {:ok, notifier} = Jellyfish.Notifier.start(server_address: "localhost:5002", server_api_token: "your-jellyfish-token")
  ```

  ```
  # Start the Notifier, specyfing what types of events it will receive from the Jellyfish
  iex> {:ok, notifier} = Jellyfish.Notifier.start(events: [:server_notifications])
  {:ok, #PID<0.301.0>}

  # Subscribe current process to all server notifications.
  iex> {:ok, _rooms} = Jellyfish.Notifier.subscribe(notifier, :server_notifications, :all)

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

  alias Jellyfish.{Room, Utils}
  alias Jellyfish.{Notification, ServerMessage}

  alias Jellyfish.ServerMessage.{
    Authenticated,
    AuthRequest,
    RoomNotFound,
    RoomsState,
    RoomState,
    RoomStateRequest,
    SubscribeRequest,
    SubscriptionResponse
  }

  @response_timeout 2000
  @subscribe_timeout 5000

  @typedoc """
  The reference to the `Notifier` process.
  """
  @type notifier() :: GenServer.server()

  @typedoc """
  The connection options used to open connection to Jellyfish, as well as `events` which the
  Notifier will be receiving from the Jellyfish.

  For more information about connecting to Jellyfish, see `t:Jellyfish.Client.connection_options/0`.
  """
  @type options() :: [
          server_address: String.t(),
          server_api_token: String.t(),
          secure?: boolean(),
          events: [:server_notification]
        ]
  @valid_events [:server_notification]

  @doc """
  Starts the Notifier process and connects to Jellyfish.

  Acts like `start/1` but links to the calling process.

  See `start/1` for more information.
  """
  @spec start_link(options()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    connect(:start_link, opts)
  end

  @doc """
  Starts the Notifier process and connects to Jellyfish.
  All event types, which the notifier should receive have to be provided using the `events` option.

  To learn how to receive notifications, see `subscribe/3`.

  For information about options, see `t:options/0`.
  """
  @spec start(options()) :: {:ok, pid()} | {:error, term()}
  def start(opts \\ []) do
    connect(:start, opts)
  end

  @doc """
  Subscribes the process to receive events of `event_type` from room with `room_id` and returns
  current state of the room.


  Note, that in order to receive a certain type of notifications, they have to be provided when starting the notifier.
  Subscribing to an `event_type` which hasn't been defined upon start results in `{:error, unsupported_event_type}`.

  If `:all` is passed in place of `room_id`, notifications about all of the rooms will be sent and
  list of all of the room's states is returned.

  Notifications are sent to the process in a form of `{:jellyfish, msg}`,
  where `msg` is one of structs defined under "Notifications" section in the docs,
  for example `{:jellyfish, %Jellyfish.Notification.RoomCrashed{room_id: "some_id"}}`.
  """
  @spec subscribe(notifier(), :server_notification, Room.id() | :all) ::
          {:ok, Room.t() | [Room.t()]} | {:error, atom()}
  def subscribe(notifier, event_type, room_id) do
    with true <- event_type in @valid_events do
      WebSockex.cast(notifier, {:subscribe, self(), event_type, room_id})

      receive do
        {:jellyfish, {:subscribe_answer, answer}} ->
          answer

        {:error, _reason} = error ->
          error
      after
        @subscribe_timeout -> {:error, :timeout}
      end
    else
      false ->
        {:error, :invalid_event_type}
    end
  end

  @impl true
  def handle_frame({:binary, msg}, state) do
    %ServerMessage{content: {_type, notification}} = ServerMessage.decode(msg)
    state = handle_notification(notification, state)

    {:ok, state}
  end

  @impl true
  def handle_cast({:subscribe, pid, event_type, _room_id} = request, state) do
    if to_proto_event_type(event_type) in state.subscribed_events do
      handle_request(request, state)
    else
      send(pid, {:error, :unsupported_event_type})
      {:ok, state}
    end
  end

  defp handle_request({:subscribe, pid, :server_notification, room_id}, state) do
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
        :all -> {:option, :OPTION_ALL}
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
      pending_subscriptions: %{},
      subscribed_events: []
    }

    with {:ok, events} <- Keyword.get(opts, :events, [:server_notification]) |> validate_events(),
         state = %{state | subscribed_events: events},
         {:ok, ws} <-
           apply(WebSockex, fun, ["#{address}/socket/server/websocket", __MODULE__, state]),
         {:jellyfish, :authenticated} <-
           send_request(ws, {:auth_request, %AuthRequest{token: api_token}}),
         {:jellyfish, :subscribed} <-
           send_request(ws, {:subscribe_request, %SubscribeRequest{event_types: events}}) do
      {:ok, ws}
    else
      {:jellyfish, :invalid_token} ->
        {:error, :invalid_token}

      {:error, _reason} = error ->
        error
    end
  end

  defp validate_events(events) do
    with true <- Enum.all?(events, fn event -> event in @valid_events end) do
      events
      |> Enum.uniq()
      |> Enum.map(&to_proto_event_type/1)
      |> then(&{:ok, &1})
    else
      false ->
        {:error, :invalid_event_type}
    end
  end

  defp send_request(ws, content) do
    request =
      %ServerMessage{content: content}
      |> ServerMessage.encode()

    with :ok <- WebSockex.send_frame(ws, {:binary, request}) do
      receive do
        response ->
          response
      after
        @response_timeout ->
          Process.exit(ws, :normal)
          {:error, :timeout}
      end
    end
  end

  defp handle_notification(%Authenticated{}, state) do
    send(state.caller_pid, {:jellyfish, :authenticated})
    state
  end

  defp handle_notification(%SubscriptionResponse{}, state) do
    send(state.caller_pid, {:jellyfish, :subscribed})
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

  defp to_proto_event_type(:server_notification), do: :EVENT_TYPE_SERVER_NOTIFICATION
end

defmodule Jellyfish.Notifier do
  @moduledoc """
  Module defining a process responsible for establishing
  WebSocket connection and receiving events from Jellyfish server.

  First, [configure the connection options](https://hexdocs.pm/jellyfish_server_sdk/readme.html#jellyfish-connection-configuration).

  ```
  # Start the Notifier
  iex> {:ok, notifier} = Jellyfish.Notifier.start()
  {:ok, #PID<0.301.0>}
  ```

  ```
  # Subscribe current process to server notifications from all rooms.
  iex> {:ok, _rooms} = Jellyfish.Notifier.subscribe_server_notifications(notifier, :all)

  # here add a room and a peer using functions from `Jellyfish.Room` module
  # you should receive a notification after the peer established connection

  iex> flush()
  {:jellyfish, %Jellyfish.Notification.PeerConnected{
    room_id: "21604fbe-8ac8-44e6-8474-98b5f50f1863",
    peer_id: "ae07f94e-0887-44c3-81d5-bfa9eac96252"
  }}
  :ok
  ```

  When starting the Notifier, you can provide the name under which the process will be registered.
  ```
  iex> {:ok, notifier} = Jellyfish.Notifier.start_link(name: Jellyfish.Notifier)
  ```

  """

  use WebSockex

  alias Jellyfish.{Room, Utils}
  alias Jellyfish.{Notification, ServerMessage}

  alias Jellyfish.ServerMessage.{
    Authenticated,
    AuthRequest,
    MetricsReport,
    SubscribeRequest,
    SubscribeResponse
  }

  alias Jellyfish.ServerMessage.SubscribeRequest.{Metrics, ServerNotification}

  alias Jellyfish.ServerMessage.SubscribeResponse.{RoomNotFound, RoomsState, RoomState}

  @auth_timeout 2000
  @subscribe_timeout 5000

  @typedoc """
  The reference to the `Notifier` process.
  """
  @type notifier() :: GenServer.server()

  @typedoc """
  Connection options used to connect to Jellyfish server.
  """
  @type options() :: [
          server_address: String.t(),
          server_api_token: String.t(),
          secure?: boolean(),
          name: GenServer.name()
        ]

  @doc """
  Starts the Notifier process and connects to Jellyfish.

  Acts like `start/1` but links to the calling process.

  See `start/1` for more information.
  """
  @spec start_link(options()) ::
          {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    connect(:start_link, opts)
  end

  @doc """
  Starts the Notifier process and connects to Jellyfish.

  To learn how to receive notifications, see `subscribe/3`.

  For information about options, see `t:Jellyfish.Client.connection_options/0`.
  """
  @spec start(options()) ::
          {:ok, pid()} | {:error, term()}
  def start(opts \\ []) do
    connect(:start, opts)
  end

  @doc """
  Subscribes the process to receive server notifications from room with `room_id` and returns
  current state of the room.

  If `:all` is passed in place of `room_id`, notifications about all of the rooms will be sent and
  list of all of the room's states is returned.

  Notifications are sent to the process in a form of `{:jellyfish, msg}`,
  where `msg` is one of structs defined under "Jellyfish.Notification" section in the docs,
  for example `{:jellyfish, %Jellyfish.Notification.RoomCrashed{room_id: "some_id"}}`.
  """
  @spec subscribe_server_notifications(notifier(), Room.id() | :all) ::
          {:ok, Room.t() | [Room.t()]} | {:error, atom()}
  def subscribe_server_notifications(notifier, room_id) do
    WebSockex.cast(notifier, {:subscribe_server_notifications, self(), room_id})

    receive do
      {:jellyfish, {:subscribe_answer, answer}} -> answer
      {:error, _reason} = error -> error
    after
      @subscribe_timeout -> {:error, :timeout}
    end
  end

  @doc """
  Subscribes the process to the WebRTC metrics from all the rooms.

  Metrics are periodically sent to the process in a form of `{:jellyfish, metrics_report}`,
  where `metrics_report` is the `Jellyfish.MetricsReport` struct.
  """

  @spec subscribe_metrics(notifier()) :: :ok | {:error, :timeout}
  def subscribe_metrics(notifier) do
    WebSockex.cast(notifier, {:subscribe_metrics, self()})

    receive do
      {:jellyfish, {:subscribe_answer, :ok}} -> :ok
    after
      @subscribe_timeout -> {:error, :timeout}
    end
  end

  @impl true
  def handle_cast({:subscribe_server_notifications, pid, room_id}, state) do
    proto_room_id =
      case room_id do
        :all -> {:option, :OPTION_ALL}
        id -> {:id, id}
      end

    request_id = UUID.uuid4()

    request =
      %ServerMessage{
        content:
          {:subscribe_request,
           %SubscribeRequest{
             id: request_id,
             event_type:
               {:server_notification,
                %ServerNotification{
                  room_id: proto_room_id
                }}
           }}
      }
      |> ServerMessage.encode()

    state = put_in(state.pending_subscriptions[request_id], {:server_notification, pid})

    {:reply, {:binary, request}, state}
  end

  def handle_cast({:subscribe_metrics, pid}, state) do
    request_id = UUID.uuid4()

    request =
      %ServerMessage{
        content:
          {:subscribe_request,
           %SubscribeRequest{id: request_id, event_type: {:metrics, %Metrics{}}}}
      }
      |> ServerMessage.encode()

    state = put_in(state.pending_subscriptions[request_id], {:metrics, pid})

    {:reply, {:binary, request}, state}
  end

  @impl true
  def handle_frame({:binary, msg}, state) do
    %ServerMessage{content: {_type, notification}} = ServerMessage.decode(msg)
    state = handle_notification(notification, state)

    {:ok, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    state =
      update_in(state.subscriptions.server_notification, fn subs ->
        Map.new(subs, fn {id, pids} -> {id, MapSet.delete(pids, pid)} end)
      end)
      |> update_in([:subscriptions, :metrics], &MapSet.delete(&1, pid))

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
      subscriptions: %{
        server_notification: %{all: MapSet.new()},
        metrics: MapSet.new()
      },
      pending_subscriptions: %{}
    }

    auth_msg =
      %ServerMessage{content: {:auth_request, %AuthRequest{token: api_token}}}
      |> ServerMessage.encode()

    websockex_opts = Keyword.take(opts, [:name])

    with {:ok, ws} <-
           apply(WebSockex, fun, [
             "#{address}/socket/server/websocket",
             __MODULE__,
             state,
             websockex_opts
           ]),
         :ok <- WebSockex.send_frame(ws, {:binary, auth_msg}) do
      receive do
        {:jellyfish, :authenticated} ->
          {:ok, ws}

        {:jellyfish, :invalid_token} ->
          {:error, :invalid_token}
      after
        @auth_timeout ->
          Process.exit(ws, :normal)
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

  defp handle_notification(%SubscribeResponse{id: id, content: content}, state) do
    {{event_type, pid}, state} = pop_in(state.pending_subscriptions[id])

    handle_subscription_response(event_type, pid, content, state)
  end

  defp handle_notification(%{room_id: room_id} = message, state) do
    state.subscriptions.server_notification
    |> Map.take([:all, room_id])
    |> Map.values()
    |> Enum.reduce(fn pids, acc -> MapSet.union(pids, acc) end)
    |> Enum.each(&send(&1, {:jellyfish, Notification.to_notification(message)}))

    state
  end

  defp handle_notification(%MetricsReport{metrics: metrics}, state) do
    notification = %Jellyfish.MetricsReport{metrics: Jason.decode!(metrics)}

    state.subscriptions.metrics
    |> Enum.each(fn pid ->
      send(pid, {:jellyfish, notification})
    end)

    state
  end

  defp handle_subscription_response(:server_notification, pid, {_type, %RoomNotFound{}}, state) do
    send(pid, {:jellyfish, {:subscribe_answer, {:error, :room_not_found}}})
    state
  end

  defp handle_subscription_response(:server_notification, pid, {_type, %mod{} = room}, state)
       when mod in [RoomState, RoomsState] do
    {room_id, room} =
      case mod do
        RoomState -> {room.id, Room.from_proto(room)}
        RoomsState -> {:all, Enum.map(room.rooms, &Room.from_proto/1)}
      end

    Process.monitor(pid)

    state =
      update_in(state.subscriptions.server_notification[room_id], fn
        nil -> MapSet.new([pid])
        set -> MapSet.put(set, pid)
      end)

    send(pid, {:jellyfish, {:subscribe_answer, {:ok, room}}})
    state
  end

  defp handle_subscription_response(:metrics, pid, nil, state) do
    Process.monitor(pid)

    state = update_in(state.subscriptions.metrics, &MapSet.put(&1, pid))

    send(pid, {:jellyfish, {:subscribe_answer, :ok}})
    state
  end
end

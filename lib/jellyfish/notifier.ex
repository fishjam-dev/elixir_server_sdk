defmodule Jellyfish.Notifier do
  @moduledoc """
  Module defining a process responsible for establishing
  WebSocket connection and receiving events from Jellyfish server.

  First, [configure the connection options](README.md#jellyfish-connection-configuration).

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
    RoomNotFound,
    RoomState,
    RoomStateRequest,
    SubscribeRequest,
    SubscribeResponse
  }

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
  @spec start_link(options()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    connect(:start_link, opts)
  end

  @doc """
  Starts the Notifier process and connects to Jellyfish.

  To learn how to receive notifications, see `subscribe/3`.

  For information about options, see `t:Jellyfish.Client.connection_options/0`.
  """
  @spec start(options()) :: {:ok, pid()} | {:error, term()}
  def start(opts \\ []) do
    connect(:start, opts)
  end

  @doc """
  Subscribes the process to receive server notifications from room with `room_id` and returns
  current state of the room.

  If `:all` is passed in place of `room_id`, notifications about all of the rooms will be sent and
  `:ok` is returned.

  Notifications are sent to the process in a form of `{:jellyfish, msg}`,
  where `msg` is one of structs defined under "Jellyfish.Notification" section in the docs,
  for example `{:jellyfish, %Jellyfish.Notification.RoomCrashed{room_id: "some_id"}}`.
  """
  @spec subscribe_server_notifications(notifier(), Room.id() | :all) ::
          :ok | {:ok, Room.t()} | {:error, atom()}
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
  def handle_cast({:subscribe_server_notifications, pid, :all}, state) do
    if :server_notification in state.subscribed_events do
      send(pid, {:jellyfish, {:subscribe_answer, :ok}})
      state = update_in(state.subscriptions.server_notification[:all], &MapSet.put(&1, pid))
      {:ok, state}
    else
      {request, state} = subscribe_request_server_notification(pid, :all, state)
      {:reply, {:binary, ServerMessage.encode(request)}, state}
    end
  end

  @impl true
  def handle_cast({:subscribe_server_notifications, pid, room_id}, state) do
    {request, state} =
      if :server_notification in state.subscribed_events do
        room_state_request(room_id, pid, state)
      else
        subscribe_request_server_notification(pid, room_id, state)
      end

    {:reply, {:binary, ServerMessage.encode(request)}, state}
  end

  def handle_cast({:subscribe_metrics, pid}, state) do
    if :metrics in state.subscribed_events do
      send(pid, {:jellyfish, {:subscribe_answer, :ok}})
      state = update_in(state.subscriptions[:metrics], &MapSet.put(&1, pid))
      {:ok, state}
    else
      {request, state} = subscribe_request_metrics(pid, state)
      {:reply, {:binary, ServerMessage.encode(request)}, state}
    end
  end

  @impl true
  def handle_frame({:binary, msg}, state) do
    %ServerMessage{content: {_type, notification}} = ServerMessage.decode(msg)

    handle_notification(notification, state)
  end

  @impl true
  def handle_info({:subscribe_server_notification, pid, room_id}, state) do
    {request, state} = room_state_request(room_id, pid, state)
    {:reply, {:binary, ServerMessage.encode(request)}, state}
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
      subscribed_events: [],
      subscriptions: %{
        server_notification: %{all: MapSet.new()},
        metrics: MapSet.new()
      },
      pending_subscriptions: %{},
      pending_room_state_requests: %{}
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
    {:ok, state}
  end

  defp handle_notification(%SubscribeResponse{event_type: :EVENT_TYPE_SERVER_NOTIFICATION}, state) do
    {pending_subscriptions, state} = pop_in(state.pending_subscriptions[:server_notification])
    state = update_in(state.subscribed_events, &List.insert_at(&1, 0, :server_notification))

    state =
      pending_subscriptions
      |> Enum.reduce(state, fn
        {pid, :all}, state ->
          send(pid, {:jellyfish, {:subscribe_answer, :ok}})
          update_in(state.subscriptions.server_notification[:all], &MapSet.put(&1, pid))

        {pid, room_id}, state ->
          send(self(), {:subscribe_server_notification, pid, room_id})
          state
      end)

    {:ok, state}
  end

  defp handle_notification(%SubscribeResponse{event_type: :EVENT_TYPE_METRICS}, state) do
    {pids, state} = pop_in(state.pending_subscriptions[:metrics])

    pids
    |> Enum.each(&send(&1, {:jellyfish, {:subscribe_answer, :ok}}))

    state = update_in(state.subscriptions.metrics, &MapSet.union(&1, MapSet.new(pids)))
    state = update_in(state.subscribed_events, &List.insert_at(&1, 0, :metrics))

    {:ok, state}
  end

  defp handle_notification(%RoomState{id: room_id} = room, state) do
    {pids, state} = pop_in(state.pending_room_state_requests[room_id])

    room = Room.from_proto(room)

    pids
    |> Enum.each(fn pid ->
      send(pid, {:jellyfish, {:subscribe_answer, {:ok, room}}})
      Process.monitor(pid)
    end)

    state =
      update_in(state.subscriptions.server_notification[room_id], fn
        nil -> MapSet.new(pids)
        set -> MapSet.union(set, MapSet.new(pids))
      end)

    {:ok, state}
  end

  defp handle_notification(%RoomNotFound{room_id: room_id}, state) do
    {pids, state} = pop_in(state.pending_room_state_requests[room_id])

    pids
    |> Enum.each(fn pid ->
      send(pid, {:jellyfish, {:subscribe_answer, {:error, :room_not_found}}})
      Process.monitor(pid)
    end)

    {:ok, state}
  end

  defp handle_notification(%{room_id: room_id} = message, state) do
    state.subscriptions.server_notification
    |> Map.take([:all, room_id])
    |> Map.values()
    |> Enum.reduce(fn pids, acc -> MapSet.union(pids, acc) end)
    |> Enum.each(&send(&1, {:jellyfish, Notification.to_notification(message)}))

    {:ok, state}
  end

  defp handle_notification(%MetricsReport{metrics: metrics}, state) do
    notification = %Jellyfish.MetricsReport{metrics: Jason.decode!(metrics)}

    state.subscriptions.metrics
    |> Enum.each(fn pid ->
      send(pid, {:jellyfish, notification})
    end)

    {:ok, state}
  end

  defp subscribe_request_server_notification(caller_pid, room_id, state) do
    request = %ServerMessage{
      content:
        {:subscribe_request, %SubscribeRequest{event_type: :EVENT_TYPE_SERVER_NOTIFICATION}}
    }

    state =
      update_in(
        state.pending_subscriptions[:server_notification],
        fn
          nil -> [{caller_pid, room_id}]
          list -> List.insert_at(list, 0, {caller_pid, room_id})
        end
      )

    {request, state}
  end

  defp subscribe_request_metrics(caller_pid, state) do
    request = %ServerMessage{
      content: {:subscribe_request, %SubscribeRequest{event_type: :EVENT_TYPE_METRICS}}
    }

    state =
      update_in(state.pending_subscriptions[:metrics], fn
        nil -> [caller_pid]
        list -> List.insert_at(list, 0, caller_pid)
      end)

    {request, state}
  end

  defp room_state_request(room_id, caller_pid, state) do
    request = %ServerMessage{
      content: {:room_state_request, %RoomStateRequest{room_id: room_id}}
    }

    state =
      update_in(state.pending_room_state_requests[room_id], fn
        nil -> [caller_pid]
        list -> List.insert_at(list, 0, caller_pid)
      end)

    {request, state}
  end
end

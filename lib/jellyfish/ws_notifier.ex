defmodule Jellyfish.WSNotifier do
  @moduledoc """
  Module defining a process responsible for establishing
  WebSocket connection and receiving events from Jellyfish server.

  First, [configure the connection options](README.md#jellyfish-connection-configuration).

  ```
  # Start the Notifier
  iex> {:ok, notifier} = Jellyfish.WSNotifier.start()
  {:ok, #PID<0.301.0>}
  ```

  ```
  # Subscribe current process to server notifications.
  iex> :ok = Jellyfish.WSNotifier.subscribe_server_notifications(notifier)

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
  iex> {:ok, notifier} = Jellyfish.WSNotifier.start_link(name: Jellyfish.WSNotifier)
  ```

  """

  use WebSockex

  require Logger

  alias Jellyfish.Utils
  alias Jellyfish.{Notification, ServerMessage}

  alias Jellyfish.ServerMessage.{
    Authenticated,
    AuthRequest,
    MetricsReport,
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
  Subscribes the process to receive server notifications from all the rooms.

  Notifications are sent to the process in a form of `{:jellyfish, msg}`,
  where `msg` is one of structs defined under "Jellyfish.Notification" section in the docs,
  for example `{:jellyfish, %Jellyfish.Notification.RoomCrashed{room_id: "some_id"}}`.
  """
  @spec subscribe_server_notifications(notifier()) :: :ok | {:error, atom()}
  def subscribe_server_notifications(notifier) do
    WebSockex.cast(notifier, {:subscribe_server_notifications, self()})

    receive do
      {:jellyfish, {:subscribe_answer, :ok}} -> :ok
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
  def handle_cast({:subscribe_server_notifications, pid}, state) do
    {request, state} = subscribe_request(:server_notification, pid, state)
    {:reply, {:binary, ServerMessage.encode(request)}, state}
  end

  def handle_cast({:subscribe_metrics, pid}, state) do
    {request, state} = subscribe_request(:metrics, pid, state)
    {:reply, {:binary, ServerMessage.encode(request)}, state}
  end

  def handle_cast(:terminate, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_frame({:binary, msg}, state) do
    case ServerMessage.decode(msg) do
      %ServerMessage{content: {_type, notification}} ->
        handle_notification(notification, state)

      %ServerMessage{content: nil, __unknown_fields__: _binary} ->
        Logger.warning(
          "Can't decode received notification. This probably means that jellyfish is using a different version of protobuffs."
        )

        {:ok, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    state =
      [:server_notification, :metrics]
      |> Enum.reduce(state, fn event_type, state ->
        update_in(state.subscriptions[event_type], &MapSet.delete(&1, pid))
      end)

    {:ok, state}
  end

  @impl true
  def terminate({:remote, 1000, "invalid token"}, state) do
    IO.inspect("TERMINATE", label: :WTF)
    send(state.caller_pid, {:jellyfish, :invalid_token})
  end

  @impl true
  def terminate(reason, _state) do
    IO.inspect("TERMINATE #{inspect(reason)}", label: :WTF)
    :ok
  end

  defp connect(fun, opts) do
    {address, api_token, secure?} = Utils.get_options_or_defaults(opts)
    address = if secure?, do: "wss://#{address}", else: "ws://#{address}"

    empty_subscriptions = %{server_notification: MapSet.new(), metrics: MapSet.new()}

    state = %{
      caller_pid: self(),
      subscriptions: empty_subscriptions,
      pending_subscriptions: empty_subscriptions
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

  defp handle_notification(%SubscribeResponse{event_type: proto_event_type}, state) do
    event_type = from_proto_event_type(proto_event_type)

    {pending_subscriptions, state} = pop_in(state.pending_subscriptions[event_type])

    state =
      if Enum.empty?(pending_subscriptions) do
        state
      else
        pending_subscriptions
        |> Enum.reduce(state, fn
          pid, state ->
            send(pid, {:jellyfish, {:subscribe_answer, :ok}})
            update_in(state.subscriptions[event_type], &MapSet.put(&1, pid))
        end)
      end

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

  defp handle_notification(%{room_id: _room_id} = message, state) do
    state.subscriptions.server_notification
    |> Enum.each(&send(&1, {:jellyfish, Notification.to_notification(message)}))

    {:ok, state}
  end

  defp subscribe_request(event_type, caller_pid, state) do
    request = %ServerMessage{
      content:
        {:subscribe_request, %SubscribeRequest{event_type: to_proto_event_type(event_type)}}
    }

    state = update_in(state.pending_subscriptions[event_type], &MapSet.put(&1, caller_pid))

    {request, state}
  end

  defp from_proto_event_type(:EVENT_TYPE_SERVER_NOTIFICATION), do: :server_notification
  defp from_proto_event_type(:EVENT_TYPE_METRICS), do: :metrics

  defp to_proto_event_type(:server_notification), do: :EVENT_TYPE_SERVER_NOTIFICATION
  defp to_proto_event_type(:metrics), do: :EVENT_TYPE_METRICS
end

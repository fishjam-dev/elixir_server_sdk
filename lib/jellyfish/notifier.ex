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
  {:jellyfish_notification,
   %{
     id: "5110be31-a252-42af-b833-047edaade500",
     room_id: "fd3d1512-3d4d-4e6a-9697-7b132aa0adf6",
     type: :peer_connected
   }}
  :ok
  ```
  """

  use WebSockex

  alias Jellyfish.{Client, Utils}
  alias Jellyfish.Exception.StructureError

  @auth_timeout 2000

  @doc """
  Starts the Notifier process and connects to Jellyfish. 

  Acts like `start/1` but links to the calling process.

  See `start/1` for more information.
  """
  @spec start_link(Client.connection_options()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    case start(opts) do
      {:ok, pid} ->
        Process.link(pid)
        {:ok, pid}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Starts the Notifier process and connects to Jellyfish. 

  Received notifications are send to the calling process in
  a form of `{:jellyfish_notification, msg}`.

  For information about options, see `t:Jellyfish.Client.connection_options/0`.
  """
  @spec start(Client.connection_options()) :: {:ok, pid()} | {:error, term()}
  def start(opts \\ []) do
    {address, api_token, secure?} = Utils.get_options_or_defaults(opts)
    address = if secure?, do: "wss://#{address}", else: "ws://#{address}"
    state = %{receiver_pid: self()}

    auth_msg =
      %{type: "controlMessage", data: %{type: "authRequest", token: api_token}}
      |> Jason.encode!()

    with {:ok, pid} <- WebSockex.start("#{address}/socket/server/websocket", __MODULE__, state),
         :ok <- WebSockex.send_frame(pid, {:text, auth_msg}) do
      receive do
        {:jellyfish_notification, %{type: :authenticated}} ->
          {:ok, pid}

        {:jellyfish_notification, %{type: :invalid_token}} ->
          Process.exit(pid, :normal)
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

  @impl true
  def handle_frame({:text, msg}, state) do
    with {:ok, decoded_msg} <- Jason.decode(msg),
         %{"type" => "controlMessage", "data" => data} <- decoded_msg,
         {:ok, notification} <- decode_notification(data) do
      send(state.receiver_pid, {:jellyfish_notification, notification})
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
    send(state.receiver_pid, {:jellyfish_notification, %{type: :invalid_token}})
  end

  defp decode_notification(%{"type" => type, "roomId" => room_id, "id" => id}) do
    decoded_type =
      case type do
        "authenticated" -> :authenticated
        "peerConnected" -> :peer_connected
        "peerDisconnected" -> :peer_disconected
        "componentCrashed" -> :component_crashed
        _other -> nil
      end

    if is_nil(decoded_type) do
      {:error, :invalid_type}
    else
      {:ok, %{type: decoded_type, room_id: room_id, id: id}}
    end
  end

  defp decode_notification(%{"type" => type, "room_id" => id}) do
    decoded_type =
      case type do
        "roomCrashed" -> :room_crashed
        _other -> nil
      end

    if is_nil(decoded_type),
      do: {:error, :invalid_type},
      else: {:ok, %{type: decoded_type, room_id: id}}
  end

  defp decode_notification(%{"type" => type}) do
    decoded_type =
      case type do
        "authenticated" -> :authenticated
        _other -> nil
      end

    if is_nil(decoded_type), do: {:error, :invalid_type}, else: {:ok, %{type: decoded_type}}
  end

  defp decode_notification(_other), do: {:error, :invalid_type}
end

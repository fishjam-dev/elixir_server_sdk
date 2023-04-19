defmodule Jellyfish.Notifier do
  @moduledoc """
  This module defines a process responsible for establishing
  WebSocket connection and receiving notifications form Jellyfish server.

  ```
  iex> {:ok, pid} = Jellyfish.Notifier.start("ws://address-of-jellyfish-server.com", "your-jellyfish-token")
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

  alias Jellyfish.{Exception, Utils}

  @auth_timeout 2000

  @doc """
  Starts the Notifier process and connects to Jellyfish. 

  Acts like `start/1` but links to the calling process.

  See `start/1` for more information.
  """
  @spec start_link(server_address: String.t(), server_api_token: String.t()) ::
          {:ok, pid()} | {:error, term()}
  def start_link(opts) do
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

  ## Options

    * `:server_address` - url or IP address of the Jellyfish server instance.
    * `:server_api_token` - token used for authorizing HTTP requests. It's the same
    token as the one configured in Jellyfish.

  When an option is not explicily passed, value set in `config.exs` is used:
  ```
  # in config.exs
  config :jellyfish_server_sdk, 
    server_address: "http://you-jellyfish-server-address.com",
    server_api_token: "your-jellyfish-token",
  ```
  """
  @spec start(server_address: String.t(), server_api_token: String.t()) ::
          {:ok, pid()} | {:error, term()}
  def start(opts) do
    state = %{receiver_pid: self()}

    with {:ok, {address, api_token}} <- Utils.get_options_or_defaults(opts),
         address <- convert_url_prefix(address),
         {:ok, pid} <- WebSockex.start("#{address}/socket/server/websocket", __MODULE__, state),
         auth_msg <-
           Jason.encode!(%{type: "controlMessage", data: %{type: "authRequest", token: api_token}}),
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
      _other -> raise Exception.NotificationStructureError
    end

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

  defp convert_url_prefix(url) do
    # assumes that url starts with valid prefix, like "http://"
    [prefix, address] = String.split(url, ":", parts: 2)

    new_prefix =
      case prefix do
        "http" -> "ws"
        "https" -> "wss"
      end

    "#{new_prefix}:#{address}"
  end
end

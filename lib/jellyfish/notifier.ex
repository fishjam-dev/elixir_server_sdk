defmodule Jellyfish.Notifier do
  @moduledoc """
  TODO
  """

  use WebSockex

  alias Jellyfish.Exception

  def start_link(pid, url) do
    token = Application.fetch_env!(:jellyfish_server_sdk, :token)
    start_link(pid, url, token)
  end

  def start_link(pid, url, token) do
    state = %{receiver_pid: pid}

    auth_msg =
      %{type: "controlMessage", data: %{type: "authRequest", token: token}}
      |> Jason.encode!()

    with {:ok, pid} <- WebSockex.start("ws://#{url}/socket/server/websocket", __MODULE__, state),
         :ok <- WebSockex.send_frame(pid, {:text, auth_msg}) do
      Process.link(pid)
      {:ok, pid}
    else
      {:error, _reason} = error ->
        Process.exit(pid, :normal)
        error
    end
  end

  def handle_frame({:text, msg}, state) do
    with {:ok, decoded_msg} <- Jason.decode(msg),
         %{"type" => "controlMessage", "data" => data} <- decoded_msg |> IO.inspect(),
         %{"type" => type, "id" => id} <- data,
         {:ok, decoded_type} <- decode_type(type) do
      send(state.receiver_pid, {decoded_type, id})
    else
      _other -> raise Exception.NotificationStructureError
    end

    {:ok, state}
  end

  defp decode_type(type) do
    decoded_type =
      case type do
        "authenticated" -> :authenticated
        "peerConnected" -> :peer_connected
        "peerDisconnected" -> :peer_disconected
        "roomCrashed" -> :room_crashed
        "componentCrashed" -> :component_crashed
        _other -> nil
      end

    if is_nil(decoded_type), do: {:error, :invalid_type}, else: {:ok, decoded_type}
  end
end

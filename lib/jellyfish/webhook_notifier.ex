defmodule Fishjam.WebhookNotifier do
  @moduledoc """
  Module defining a function allowing decoding received webhook notification from fishjam to notification structs.
  """

  require Logger

  alias Fishjam.{Notification, ServerMessage}

  @doc """
  Decodes received webhook to notification structs.

  ```
  iex>  <<18, 76, 10, 36, 102, 98, 102, 52, 49, 57, 48, 99, 45, 53, 99, 55, 54, 45, 52,
  ...>  49, 53, 99, 45, 56, 57, 51, 57, 45, 53, 50, 99, 54, 101, 100, 50, 48, 56, 54,
  ...>  56, 98, 18, 36, 99, 55, 50, 51, 54, 53, 56, 55, 45, 53, 100, 102, 56, 45, 52,
  ...>  98, 52, 49, 45, 98, 54, 101, 52, 45, 50, 54, 56, 101, 55, 49, 49, 51, 51, 101,
  ...>  101, 50>>
  ...> |> Fishjam.WebhookNotifier.receive()
  %Fishjam.Notification.PeerConnected{
  room_id: "fbf4190c-5c76-415c-8939-52c6ed20868b",
  peer_id: "c7236587-5df8-4b41-b6e4-268e71133ee2"
  }
  iex>  Fishjam.WebhookNotifier.receive(<<>>)
  {:error, :unknown_server_message}
  ```
  """
  @spec receive(term()) :: struct() | {:error, :unknown_server_message}
  def receive(binary) do
    case ServerMessage.decode(binary) do
      %ServerMessage{content: {_type, notification}} ->
        Notification.to_notification(notification)

      %ServerMessage{content: nil, __unknown_fields__: _binary} ->
        Logger.warning(
          "Can't decode received notification. This probably means that fishjam is using a different version of protobuffs."
        )

        {:error, :unknown_server_message}
    end
  end
end

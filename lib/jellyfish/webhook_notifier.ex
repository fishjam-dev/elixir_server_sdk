defmodule Jellyfish.WebhookNotifier do
  @moduledoc """
  Module defining a function allowing decoding received webhook notification from jellyfish to notification structs.
  """

  alias Jellyfish.{Notification, ServerMessage}

  @doc """
  Decode received webhook to notification structs.

  ```
  iex> %{
  ...>  "notification" => <<18, 76, 10, 36, 102, 98, 102, 52, 49, 57, 48, 99, 45, 53, 99, 55, 54, 45, 52,
  ...>  49, 53, 99, 45, 56, 57, 51, 57, 45, 53, 50, 99, 54, 101, 100, 50, 48, 56, 54,
  ...>  56, 98, 18, 36, 99, 55, 50, 51, 54, 53, 56, 55, 45, 53, 100, 102, 56, 45, 52,
  ...>  98, 52, 49, 45, 98, 54, 101, 52, 45, 50, 54, 56, 101, 55, 49, 49, 51, 51, 101,
  ...>  101, 50>>
  ...> } |> Jellyfish.WebhookNotifier.receive()
  %Jellyfish.Notification.PeerConnected{
  room_id: "fbf4190c-5c76-415c-8939-52c6ed20868b",
  peer_id: "c7236587-5df8-4b41-b6e4-268e71133ee2"
  }
  ```
  """
  @spec receive(term()) :: struct()
  def receive(json) do
    %ServerMessage{content: {_type, notification}} =
      json
      |> Map.get("notification")
      |> ServerMessage.decode()

    Notification.to_notification(notification)
  end
end

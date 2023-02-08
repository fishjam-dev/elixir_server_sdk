defmodule Jellyfish.SDK.Peer do
  @moduledoc """
  Utilities for manipulating the peers.

  ## Examples
  ```
  iex> room.id
  "d3af274a-c975-4876-9e1c-4714da0249b8"

  iex> {:ok, peer} = Jellyfish.SDK.Peer.add_peer(client, room.id, "webrtc")
  {:ok
    %Jellyfish.SDK.Peer{
      id: 3a645faa-59d1-4f94-ae6a-83c65c695ec5,
      type: "webrtc"
    }
  }

  iex> :ok = Jellyfish.SDK.Peer.delete_peer(client, room.id, peer.id)
  :ok
  ```
  """

  alias Jellyfish.SDK.{Client, Utils}
  alias Tesla.Env

  @enforce_keys [
    :id,
    :type
  ]
  defstruct @enforce_keys

  @typedoc """
  Struct that stores information about the peer.

  * `id` - id (uuid) of the peer
  * `type` - type of the peer
  """
  @type t :: %__MODULE__{
          id: String.t(),
          type: String.t()
        }

  @doc ~S"""
  Send request to add peer to specified room.

  ## Parameters

    * `client` - instance of `t:Jellyfish.SDK.Client.t/0`
    * `room_id` - id of the room that the peer will be added to
    * `type` - type of the peer
  """
  @spec add_peer(Client.t(), String.t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def add_peer(client, room_id, type) do
    case Tesla.post(
           client.http_client,
           "/room/" <> room_id <> "/peer",
           %{"type" => type},
           headers: [{"content-type", "application/json"}]
         ) do
      {:ok, %Env{status: 201, body: body}} -> {:ok, peer_from_json(Map.fetch!(body, "data"))}
      error -> Utils.translate_error_response(error)
    end
  end

  @doc ~S"""
  Send request to delete peer from specified room.

  ## Parameters

    * `client` - instance of `t:Jellyfish.SDK.Client.t/0`
    * `room_id` - id of the room that the peer will be deleted from
    * `peer_id` - id of the peer that will be deleted
  """
  @spec delete_peer(Client.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def delete_peer(client, room_id, peer_id) do
    case Tesla.delete(
           client.http_client,
           "/room/" <> room_id <> "/peer/" <> peer_id
         ) do
      {:ok, %Env{status: 204}} -> :ok
      error -> Utils.translate_error_response(error)
    end
  end

  @doc ~S"""
  Maps a `"data"` field of request response body from string keys to atom keys. Will fail if the input structure is invalid.

  ## Parameters

    * `response` - a map representing JSON response
  """
  @spec peer_from_json(map()) :: t()
  def peer_from_json(response) do
    # fails when response structure is ivalid
    %{
      "id" => id,
      "type" => type
    } = response

    %__MODULE__{
      id: id,
      type: type
    }
  end
end

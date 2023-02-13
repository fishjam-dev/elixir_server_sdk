defmodule Jellyfish.SDK.Room do
  @moduledoc """
  Utilities for manipulating the rooms.

  ## Examples
  ```
  iex> {:ok, room} = Jellyfish.SDK.Room.create_room(client, 10)
  {:ok,
    %Jellyfish.SDK.Room{
      components: [],
      config: %{max_peers: 10},
      id: "d3af274a-c975-4876-9e1c-4714da0249b8",
      peers: []
  }}

  iex> {:ok, rooms} = Jellyfish.SDK.Room.get_room_by_id(client, room.id)
  {:ok,
    [
      %Jellyfish.SDK.Room{
        components: [],
        config: %{max_peers: 10},
        id: "d3af274a-c975-4876-9e1c-4714da0249b8",
        peers: []
      }
    ]
  }

  iex> :ok = Jellyfish.SDK.Room.delete_room(room.id)
  :ok
  ```
  """

  alias Tesla.Env
  alias Jellyfish.SDK.{Client, Component, Peer, Utils}

  @enforce_keys [
    :id,
    :config,
    :components,
    :peers
  ]
  defstruct @enforce_keys

  @typedoc """
  Struct that stores information about the room.

  * `id` - id (uuid) of the room
  * `config` - map with configuration option of the room
  * `components` - list of components used by the room
  * `peers` - list of peers connected to the room
  """
  @type t :: %__MODULE__{
          id: String.t(),
          config: map(),
          components: [Component.t()],
          peers: [Peer.t()]
        }

  @doc ~S"""
  Sends request to create new room.

  ## Parameters

    * `client` - instance of `t:Jellyfish.SDK.Client.t/0`
    * `max_peers` - maximum number of peers allowed in the room at the same time, unlimited when `nil` is passed
  """
  @spec create_room(Client.t(), non_neg_integer() | nil) :: {:ok, t()} | {:error, String.t()}
  def create_room(client, max_peers) do
    case Tesla.post(
           client.http_request,
           "/room",
           %{"maxPeers" => max_peers},
           headers: [{"content-type", "application/json"}]
         ) do
      {:ok, %Env{status: 201, body: body}} ->
        {:ok, room_from_json(Map.fetch!(body, "data"))}

      error ->
        Utils.translate_error_response(error)
    end
  end

  @doc ~S"""
  Sends request to delete specified room.

  ## Parameters

    * `client` - instance of `t:Jellyfish.SDK.Client.t/0`
    * `room_id` - id of the room that will be deleted
  """
  @spec delete_room(Client.t(), String.t()) :: :ok | {:error, String.t()}
  def delete_room(client, room_id) do
    case Tesla.delete(client.http_request, "/room/#{room_id}") do
      {:ok, %Env{status: 204}} -> :ok
      error -> Utils.translate_error_response(error)
    end
  end

  @doc ~S"""
  Sends request for specified room metadata.

  ## Parameters

    * `client` - instance of `t:Jellyfish.SDK.Client.t/0`
  """
  @spec get_rooms(Client.t()) :: {:ok, [t()]} | {:error, String.t()}
  def get_rooms(client) do
    case Tesla.get(client.http_request, "/room") do
      {:ok, %Env{status: 200, body: body}} ->
        result =
          body
          |> Map.fetch!("data")
          |> Enum.map(&room_from_json/1)

        {:ok, result}

      error ->
        Utils.translate_error_response(error)
    end
  end

  @doc ~S"""
  Sends request for specified room metadata.

  ## Parameters

    * `client` - instance of `t:Jellyfish.SDK.Client.t/0`
    * `room_id` - id of the room which metadata is requested
  """
  @spec get_room_by_id(Client.t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def get_room_by_id(client, room_id) do
    case Tesla.get(client.http_request, "/room/#{room_id}") do
      {:ok, %Env{status: 200, body: body}} ->
        {:ok, room_from_json(Map.fetch!(body, "data"))}

      error ->
        Utils.translate_error_response(error)
    end
  end

  @doc ~S"""
  Maps a `"data"` field of request response body from string keys to atom keys. Will fail if the input structure is invalid.

  ## Parameters

    * `response` - a map representing JSON response
  """
  @spec room_from_json(map()) :: t()
  def room_from_json(response) do
    # fails when response structure is invalid
    %{
      "id" => id,
      "config" => %{"maxPeers" => max_peers},
      "components" => components,
      "peers" => peers
    } = response

    %__MODULE__{
      id: id,
      config: %{max_peers: max_peers},
      components: Enum.map(components, &Component.component_from_json/1),
      peers: Enum.map(peers, &Peer.peer_from_json/1)
    }
  end
end

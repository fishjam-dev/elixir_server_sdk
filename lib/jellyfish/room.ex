defmodule Jellyfish.Room do
  @moduledoc """
  Utilities for manipulating the rooms.

  ## Examples
  ```
  iex> {:ok, room} = Jellyfish.Room.create(client, max_peers: 10)
  {:ok,
    %Jellyfish.Room{
      components: [],
      config: %{max_peers: 10},
      id: "d3af274a-c975-4876-9e1c-4714da0249b8",
      peers: []
  }}

  iex> {:ok, peer} = Jellyfish.Room.add_peer(client, room.id, "webrtc")
   {:ok,
    %Jellyfish.Peer{id: "5a731f2e-f49f-4d58-8f64-16a5c09b520e", type: "webrtc"}}

  iex> :ok = Jellyfish.Room.delete(client, room.id)
  :ok
  ```
  """

  alias Tesla.Env
  alias Jellyfish.{Client, Component, Peer, Utils}
  alias Jellyfish.Exception.ResponseStructureError

  @enforce_keys [
    :id,
    :config,
    :components,
    :peers
  ]
  defstruct @enforce_keys

  @typedoc """
  Id of the room, unique within Jellyfish instance.
  """
  @type id :: String.t()

  @typedoc """
  Type describing room options.

    * `:max_peers` - maximum number of peers present in a room simultaneously. Unlimited, if not specified.
  """
  @type room_options :: [{:max_peers, non_neg_integer()}]

  @typedoc """
  Type describing component options.
  For the list of available options, please refer to the component's documentation
  """
  @type component_options :: Keyword.t()

  @typedoc """
  Stores information about the room.
  """
  @type t :: %__MODULE__{
          id: id(),
          config: map(),
          components: [Component.t()],
          peers: [Peer.t()]
        }

  @doc """
  List metadata of all of the rooms.
  """
  @spec list(Client.t()) :: {:ok, [t()]} | {:error, String.t()}
  def list(client) do
    case Tesla.get(client.http_client, "/room") do
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

  @doc """
  Get metadata of the room with `room_id`.
  """
  @spec get_by_id(Client.t(), id()) :: {:ok, t()} | {:error, String.t()}
  def get_by_id(client, room_id) do
    case Tesla.get(client.http_client, "/room/#{room_id}") do
      {:ok, %Env{status: 200, body: body}} ->
        {:ok, room_from_json(Map.fetch!(body, "data"))}

      error ->
        Utils.translate_error_response(error)
    end
  end

  @doc """
  Create a room.
  """
  @spec create(Client.t(), room_options()) :: {:ok, t()} | {:error, String.t()}
  def create(client, opts \\ []) do
    case Tesla.post(
           client.http_client,
           "/room",
           %{"maxPeers" => Keyword.get(opts, :max_peers)},
           headers: [{"content-type", "application/json"}]
         ) do
      {:ok, %Env{status: 201, body: body}} ->
        {:ok, room_from_json(Map.fetch!(body, "data"))}

      error ->
        Utils.translate_error_response(error)
    end
  end

  @doc """
  Delete the room with `room_id`.
  """
  @spec delete(Client.t(), id()) :: :ok | {:error, String.t()}
  def delete(client, room_id) do
    case Tesla.delete(client.http_client, "/room/#{room_id}") do
      {:ok, %Env{status: 204}} -> :ok
      error -> Utils.translate_error_response(error)
    end
  end

  @doc """
  Add a peer to the room with `room_id`.
  """
  @spec add_peer(Client.t(), id(), Peer.type()) :: {:ok, t()} | {:error, String.t()}
  def add_peer(client, room_id, type) do
    case Tesla.post(
           client.http_client,
           "/room/#{room_id}/peer",
           %{"type" => type},
           headers: [{"content-type", "application/json"}]
         ) do
      {:ok, %Env{status: 201, body: body}} -> {:ok, peer_from_json(Map.fetch!(body, "data"))}
      error -> Utils.translate_error_response(error)
    end
  end

  @doc """
  Delete the peer with `peer_id` from the room with `room_id`.
  """
  @spec delete_peer(Client.t(), id(), Peer.id()) :: :ok | {:error, String.t()}
  def delete_peer(client, room_id, peer_id) do
    case Tesla.delete(
           client.http_client,
           "/room/#{room_id}/peer/#{peer_id}"
         ) do
      {:ok, %Env{status: 204}} -> :ok
      error -> Utils.translate_error_response(error)
    end
  end

  @doc """
  Add component to the room with `room_id`.
  """
  @spec add_component(Client.t(), id(), Component.type(), component_options()) ::
          {:ok, t()} | {:error, String.t()}
  def add_component(client, room_id, type, opts \\ []) do
    case Tesla.post(
           client.http_client,
           "/room/#{room_id}/component",
           %{
             "type" => type,
             "options" => Map.new(opts)
           },
           headers: [{"content-type", "application/json"}]
         ) do
      {:ok, %Env{status: 201, body: body}} -> {:ok, component_from_json(Map.get(body, "data"))}
      error -> Utils.translate_error_response(error)
    end
  end

  @doc """
  Delete the component with `component_id` from the room with `room_id`.
  """
  @spec delete_component(Client.t(), id(), Component.id()) :: :ok | {:error, String.t()}
  def delete_component(client, room_id, component_id) do
    case Tesla.delete(
           client.http_client,
           "/room/#{room_id}/component/#{component_id}"
         ) do
      {:ok, %Env{status: 204}} -> :ok
      error -> Utils.translate_error_response(error)
    end
  end

  defp room_from_json(response) do
    case response do
      %{
        "id" => id,
        "config" => %{"maxPeers" => max_peers},
        "components" => components,
        "peers" => peers
      } ->
        %__MODULE__{
          id: id,
          config: %{max_peers: max_peers},
          components: Enum.map(components, &component_from_json/1),
          peers: Enum.map(peers, &peer_from_json/1)
        }

      _other ->
        raise ResponseStructureError
    end
  end

  defp peer_from_json(response) do
    case response do
      %{
        "id" => id,
        "type" => type
      } ->
        %Peer{
          id: id,
          type: type
        }

      _other ->
        raise ResponseStructureError
    end
  end

  defp component_from_json(response) do
    case response do
      %{
        "id" => id,
        "type" => type
      } ->
        %Component{
          id: id,
          type: type
        }

      _other ->
        raise ResponseStructureError
    end
  end
end

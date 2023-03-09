defmodule Jellyfish.Room do
  @moduledoc """
  Utilities for manipulating the rooms.

  ## Examples
  ```
  iex> {:ok, room} = Jellyfish.Client.create_room(client)  # => %Jellyfish.Room{...}

  iex> {:ok, peer} = Jellyfish.Room.add_peer(client, room.id, "webrtc")
   {:ok,
    %Jellyfish.Peer{id: "5a731f2e-f49f-4d58-8f64-16a5c09b520e", type: "webrtc"}}
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
  @type options :: [{:max_peers, non_neg_integer()}]

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
  Add a peer to the room with `room_id`.
  """
  @spec add_peer(Client.t(), id(), Peer.type()) :: {:ok, t()} | {:error, atom() | String.t()}
  def add_peer(client, room_id, type) do
    with {:ok, %Env{status: 201, body: body}} <-
           Tesla.post(
             client.http_client,
             "/room/#{room_id}/peer",
             %{"type" => type},
             headers: [{"content-type", "application/json"}]
           ),
         {:ok, data} <- Map.fetch(body, "data"),
         result <- Utils.peer_from_json(data) do
      {:ok, result}
    else
      :error -> raise ResponseStructureError
      error -> Utils.handle_response_error(error)
    end
  end

  @doc """
  Delete the peer with `peer_id` from the room with `room_id`.
  """
  @spec delete_peer(Client.t(), id(), Peer.id()) :: :ok | {:error, atom() | String.t()}
  def delete_peer(client, room_id, peer_id) do
    case Tesla.delete(
           client.http_client,
           "/room/#{room_id}/peer/#{peer_id}"
         ) do
      {:ok, %Env{status: 204}} -> :ok
      error -> Utils.handle_response_error(error)
    end
  end

  @doc """
  Add component to the room with `room_id`.
  """
  @spec add_component(Client.t(), id(), Component.type(), Component.options()) ::
          {:ok, t()} | {:error, atom() | String.t()}
  def add_component(client, room_id, type, opts \\ []) do
    with {:ok, %Env{status: 201, body: body}} <-
           Tesla.post(
             client.http_client,
             "/room/#{room_id}/component",
             %{
               "type" => type,
               "options" => Map.new(opts)
             },
             headers: [{"content-type", "application/json"}]
           ),
         {:ok, data} <- Map.fetch(body, "data"),
         result <- Utils.component_from_json(data) do
      {:ok, result}
    else
      :error -> raise ResponseStructureError
      error -> Utils.handle_response_error(error)
    end
  end

  @doc """
  Delete the component with `component_id` from the room with `room_id`.
  """
  @spec delete_component(Client.t(), id(), Component.id()) :: :ok | {:error, atom() | String.t()}
  def delete_component(client, room_id, component_id) do
    case Tesla.delete(
           client.http_client,
           "/room/#{room_id}/component/#{component_id}"
         ) do
      {:ok, %Env{status: 204}} -> :ok
      error -> Utils.handle_response_error(error)
    end
  end
end

defmodule Jellyfish.Room do
  @moduledoc """
  Utilities for manipulating the rooms.

  ## Examples
  ```
  iex> client = Jellyfish.Client.new()
  iex> assert {:ok, %Jellyfish.Room{
  ...>    components: [],
  ...>    config: %{max_peers: 10, video_codec: nil},
  ...>    peers: []
  ...>  } = room, _jellyfish_address} = Jellyfish.Room.create(client, max_peers: 10)
  iex> room == %Jellyfish.Room{
  ...>    id: room.id,
  ...>    components: [],
  ...>    config: %{max_peers: 10, video_codec: nil},
  ...>    peers: []}
  true
  iex> assert {:ok,%Jellyfish.Peer{
  ...>    status: :disconnected,
  ...>    type: Jellyfish.Peer.WebRTC
  ...> } = peer, _peer_token} = Jellyfish.Room.add_peer(client, room.id, Jellyfish.Peer.WebRTC)
  iex> %Jellyfish.Peer{
  ...>    id: peer.id,
  ...>    status: :disconnected,
  ...>    type: Jellyfish.Peer.WebRTC} == peer
  true
  iex> :ok = Jellyfish.Room.delete(client, room.id)
  :ok
  ```
  """

  alias Tesla.Env
  alias Jellyfish.{Client, Component, Peer}
  alias Jellyfish.Exception.StructureError

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
  Peer token, created by Jellyfish. Required by client application to open connection to Jellyfish.
  """
  @type peer_token :: String.t()

  @typedoc """
  Type describing room options.

    * `:max_peers` - maximum number of peers present in a room simultaneously.
      If set to `nil` or unspecified, the number of peers is unlimited.
    * `:video_codec` - enforces specific video codec for each peer in the room.
      If set to `nil` or unspecified, any codec will be accepted.
      To use HLS component video codec has to be `:h264`.
  """
  @type options :: [max_peers: non_neg_integer() | nil, video_codec: :h264 | :vp8 | nil]

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
  @spec get_all(Client.t()) :: {:ok, [t()]} | {:error, atom() | String.t()}
  def get_all(client) do
    with {:ok, %Env{status: 200, body: body}} <- Tesla.get(client.http_client, "/room"),
         {:ok, data} <- Map.fetch(body, "data"),
         result <- Enum.map(data, &from_json/1) do
      {:ok, result}
    else
      :error -> raise StructureError
      error -> handle_response_error(error)
    end
  end

  @doc """
  Get metadata of the room with `room_id`.
  """
  @spec get(Client.t(), id()) :: {:ok, t()} | {:error, atom() | String.t()}
  def get(client, room_id) do
    with {:ok, %Env{status: 200, body: body}} <-
           Tesla.get(client.http_client, "/room/#{room_id}"),
         {:ok, data} <- Map.fetch(body, "data"),
         result <- from_json(data) do
      {:ok, result}
    else
      :error -> raise StructureError
      error -> handle_response_error(error)
    end
  end

  @doc """
  Create a room.
  """
  @spec create(Client.t(), options()) :: {:ok, t(), String.t()} | {:error, atom() | String.t()}
  def create(client, opts \\ []) do
    with {:ok, %Env{status: 201, body: body}} <-
           Tesla.post(
             client.http_client,
             "/room",
             %{
               "maxPeers" => Keyword.get(opts, :max_peers),
               "videoCodec" => Keyword.get(opts, :video_codec)
             }
           ),
         {:ok, data} <- Map.fetch(body, "data"),
         {:ok, room_json} <- Map.fetch(data, "room"),
         {:ok, jellyfish_address} <- Map.fetch(data, "jellyfish_address"),
         result <- from_json(room_json) do
      {:ok, result, jellyfish_address}
    else
      :error -> raise StructureError
      error -> handle_response_error(error)
    end
  end

  @doc """
  Delete the room with `room_id`.
  """
  @spec delete(Client.t(), id()) :: :ok | {:error, atom() | String.t()}
  def delete(client, room_id) do
    case Tesla.delete(client.http_client, "/room/#{room_id}") do
      {:ok, %Env{status: 204}} -> :ok
      error -> handle_response_error(error)
    end
  end

  @doc """
  Add a peer to the room with `room_id`.
  """
  @spec add_peer(Client.t(), id(), Peer.options() | Peer.type()) ::
          {:ok, Peer.t(), peer_token()} | {:error, atom() | String.t()}
  def add_peer(client, room_id, peer) do
    peer = if is_atom(peer), do: struct!(peer), else: peer

    with {:ok, %Env{status: 201, body: body}} <-
           Tesla.post(
             client.http_client,
             "/room/#{room_id}/peer",
             %{
               "type" => Peer.string_from_options(peer),
               "options" =>
                 Map.from_struct(peer)
                 |> Map.new(fn {k, v} -> {snake_case_to_camel_case(k), v} end)
             }
           ),
         {:ok, %{"peer" => peer, "token" => token}} <- Map.fetch(body, "data"),
         result <- Peer.from_json(peer) do
      {:ok, result, token}
    else
      :error -> raise StructureError
      error -> handle_response_error(error)
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
      error -> handle_response_error(error)
    end
  end

  @doc """
  Add component to the room with `room_id`.
  """
  @spec add_component(Client.t(), id(), Component.options() | Component.type()) ::
          {:ok, Component.t()} | {:error, atom() | String.t()}
  def add_component(client, room_id, component) do
    component = if is_atom(component), do: struct!(component), else: component

    with {:ok, %Env{status: 201, body: body}} <-
           Tesla.post(
             client.http_client,
             "/room/#{room_id}/component",
             %{
               "type" => Component.string_from_options(component),
               "options" =>
                 Map.from_struct(component)
                 |> Map.new(fn {k, v} -> {snake_case_to_camel_case(k), v} end)
             }
           ),
         {:ok, data} <- Map.fetch(body, "data"),
         result <- Component.from_json(data) do
      {:ok, result}
    else
      :error -> raise StructureError
      error -> handle_response_error(error)
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
      error -> handle_response_error(error)
    end
  end

  @doc false
  @spec from_json(map()) :: t()
  def from_json(response) do
    case response do
      %{
        "id" => id,
        "config" => %{"maxPeers" => max_peers, "videoCodec" => video_codec},
        "components" => components,
        "peers" => peers
      } ->
        %__MODULE__{
          id: id,
          config: %{max_peers: max_peers, video_codec: codec_to_atom(video_codec)},
          components: Enum.map(components, &Component.from_json/1),
          peers: Enum.map(peers, &Peer.from_json/1)
        }

      _other ->
        raise StructureError
    end
  end

  defp handle_response_error({:ok, %Env{body: %{"errors" => error}}}),
    do: {:error, "Request failed: #{error}"}

  defp handle_response_error({:ok, %Env{body: _body}}), do: raise(StructureError)
  defp handle_response_error({:error, reason}), do: {:error, reason}

  defp snake_case_to_camel_case(atom) do
    [first | rest] = Atom.to_string(atom) |> String.split("_")
    rest = rest |> Enum.map(&String.capitalize/1)
    Enum.join([first | rest])
  end

  defp codec_to_atom("h264"), do: :h264
  defp codec_to_atom("vp8"), do: :vp8
  defp codec_to_atom(nil), do: nil
end

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
  alias Jellyfish.Component.{File, HLS, RTSP}
  alias Jellyfish.{Client, Component, Peer, Utils}
  alias Jellyfish.Exception.StructureError

  @s3_keys [:access_key_id, :secret_access_key, :region, :bucket]
  @subscribe_modes [:auto, :manual]

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
  Id of the track, unique within Jellyfish instance.
  """
  @type track_id :: String.t()

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
  Lists properties of all of the rooms.
  """
  @spec get_all(Client.t()) :: {:ok, [t()]} | {:error, atom() | String.t()}
  def get_all(client) do
    with {:ok, %Env{status: 200, body: body}} <- Tesla.get(client.http_client, "/room"),
         {:ok, data} <- Map.fetch(body, "data"),
         result <- Enum.map(data, &from_json/1) do
      {:ok, result}
    else
      :error -> raise StructureError
      error -> Utils.handle_response_error(error)
    end
  end

  @doc """
  Gets properties of the room with `room_id`.
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
      error -> Utils.handle_response_error(error)
    end
  end

  @doc """
  Creates a new room.

  Returns an address of Jellyfish where the room was created.
  When running Jellyfish in a cluster, this address might be different
  than the one used in the initial call.
  Therefore, it is important to call `Jellyfish.Client.update_address/2`
  before subsequent operations like adding peers or components.
  """
  @spec create(Client.t(), options()) :: {:ok, t(), String.t()} | {:error, atom() | String.t()}
  def create(client, opts \\ []) do
    with {:ok, %Env{status: 201, body: body}} <-
           Tesla.post(
             client.http_client,
             "/room",
             %{
               "maxPeers" => Keyword.get(opts, :max_peers),
               "videoCodec" => Keyword.get(opts, :video_codec),
               "webhookUrl" => Keyword.get(opts, :webhook_url)
             }
           ),
         {:ok, data} <- Map.fetch(body, "data"),
         {:ok, room_json} <- Map.fetch(data, "room"),
         {:ok, jellyfish_address} <- Map.fetch(data, "jellyfish_address"),
         result <- from_json(room_json) do
      {:ok, result, jellyfish_address}
    else
      :error -> raise StructureError
      error -> Utils.handle_response_error(error)
    end
  end

  @doc """
  Deletes the room with `room_id`.
  """
  @spec delete(Client.t(), id()) :: :ok | {:error, atom() | String.t()}
  def delete(client, room_id) do
    case Tesla.delete(client.http_client, "/room/#{room_id}") do
      {:ok, %Env{status: 204}} -> :ok
      error -> Utils.handle_response_error(error)
    end
  end

  @doc """
  Adds a peer to the room with `room_id`.
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
      error -> Utils.handle_response_error(error)
    end
  end

  @doc """
  Deletes the peer with `peer_id` from the room with `room_id`.
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
  Adds a component to the room with `room_id`.
  """
  @spec add_component(Client.t(), id(), Component.options() | Component.type()) ::
          {:ok, Component.t()} | {:error, atom() | String.t()}
  def add_component(client, room_id, component) do
    component = if is_atom(component), do: struct!(component), else: component

    with :ok <- validate_component(component),
         {:ok, %Env{status: 201, body: body}} <-
           Tesla.post(
             client.http_client,
             "/room/#{room_id}/component",
             %{
               "type" => Component.string_from_options(component),
               "options" =>
                 Map.from_struct(component)
                 |> map_snake_case_to_camel_case()
             }
           ),
         {:ok, data} <- Map.fetch(body, "data"),
         result <- Component.from_json(data) do
      {:ok, result}
    else
      :error -> raise StructureError
      error -> Utils.handle_response_error(error)
    end
  end

  @doc """
  Deletes the component with `component_id` from the room with `room_id`.
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

  @doc """
  In order to subscribe to HLS peers/components, the HLS component should be initialized with the subscribe_mode set to :manual.
  This mode proves beneficial when you do not wish to record or stream all the available streams within a room via HLS.
  It allows for selective addition instead – you can manually select specific streams.
  For instance, you could opt to record only the stream of an event's host.
  """
  @spec hls_subscribe(Client.t(), id(), [Peer.id() | Component.id()]) ::
          :ok | {:error, atom() | String.t()}
  def hls_subscribe(client, room_id, origins) do
    with :ok <- validate_origins(origins),
         {:ok, %Env{status: 201}} <-
           Tesla.post(client.http_client, "/hls/#{room_id}/subscribe", %{origins: origins}) do
      :ok
    else
      error -> Utils.handle_response_error(error)
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

  defp validate_component(%RTSP{}), do: :ok

  defp validate_component(%File{}), do: :ok

  defp validate_component(%HLS{s3: s3, subscribe_mode: subscribe_mode}) do
    with :ok <- validate_s3_credentials(s3),
         :ok <- validate_subscribe_mode(subscribe_mode) do
      :ok
    else
      :error -> {:error, :component_validation}
    end
  end

  defp validate_component(_component), do: {:error, :component_validation}

  defp validate_s3_credentials(%{} = credentials) do
    keys = Map.keys(credentials)

    if @s3_keys -- keys == [] and keys -- @s3_keys == [],
      do: :ok,
      else: :error
  end

  defp validate_s3_credentials(nil), do: :ok
  defp validate_s3_credentials(_credentials), do: :error

  defp validate_subscribe_mode(mode) when mode in @subscribe_modes, do: :ok
  defp validate_subscribe_mode(_mode), do: :error

  defp validate_origins(origins) when is_list(origins), do: :ok
  defp validate_origins(_tracks), do: {:error, :origins_validation}

  defp map_snake_case_to_camel_case(%{} = map),
    do:
      Map.new(map, fn {k, v} -> {snake_case_to_camel_case(k), map_snake_case_to_camel_case(v)} end)

  defp map_snake_case_to_camel_case(value), do: value

  defp snake_case_to_camel_case(atom) do
    [first | rest] = Atom.to_string(atom) |> String.split("_")
    rest = rest |> Enum.map(&String.capitalize/1)
    Enum.join([first | rest])
  end

  defp codec_to_atom("h264"), do: :h264
  defp codec_to_atom("vp8"), do: :vp8
  defp codec_to_atom(nil), do: nil
end

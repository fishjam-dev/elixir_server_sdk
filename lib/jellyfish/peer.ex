defmodule Jellyfish.Peer do
  @moduledoc """
  Defines `t:Jellyfish.Peer.t/0`.

  Peer is an entity that connects to the server to publish, subscribe to or publish and subscribe
  to tracks published by components and other peers.
  For more information refer to [Jellyfish documentation](https://jellyfish-dev.github.io/jellyfish-docs/introduction/basic_concepts).
  """

  require Logger

  alias Jellyfish.Exception.StructureError
  alias Jellyfish.Peer.WebRTC
  alias Jellyfish.Track

  @enforce_keys [
    :id,
    :type,
    :status,
    :tracks,
    :metadata
  ]
  defstruct @enforce_keys

  @typedoc """
  Id of the peer, unique across within the room.
  """
  @type id :: String.t()

  @typedoc """
  Type of the peer.
  """
  @type type :: WebRTC

  @typedoc """
  Status of the peer.
  """
  @type status :: :disconnected | :connected

  @valid_status_strings ["disconnected", "connected"]

  @typedoc """
  Peer-specific options.
  """
  @type options :: WebRTC.t()

  @typedoc """
  Stores information about the peer.
  """
  @type t :: %__MODULE__{
          id: id(),
          type: type(),
          status: status(),
          tracks: [Track.t()],
          metadata: any()
        }

  @doc false
  @spec from_json(map()) :: t()
  def from_json(response) do
    case response do
      %{
        "id" => id,
        "type" => type_str,
        "status" => status_str,
        "tracks" => tracks,
        "metadata" => metadata
      } ->
        %__MODULE__{
          id: id,
          type: type_from_string(type_str),
          status: status_from_string(status_str),
          tracks: Enum.map(tracks, &Track.from_json/1),
          metadata: metadata
        }

      other ->
        Logger.warning("Unknown structure: #{other}")

        raise StructureError
    end
  end

  @doc false
  @spec string_from_options(struct()) :: String.t()
  def string_from_options(%WebRTC{}), do: "webrtc"

  defp type_from_string("webrtc"), do: WebRTC

  def status_from_string(status) when status in @valid_status_strings,
    do: String.to_atom(status)
end

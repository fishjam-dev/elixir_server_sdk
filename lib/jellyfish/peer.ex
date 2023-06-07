defmodule Jellyfish.Peer do
  @moduledoc """
  Defines `t:Jellyfish.Peer.t/0`.

  Peer is an entity that connects to the server to publish, subscribe to or publish and subscribe
  to tracks published by components and other peers.
  For more information refer to [Jellyfish documentation](https://www.membrane.stream)
  """

  alias Jellyfish.Exception.StructureError
  alias Jellyfish.Peer.WebRTC

  @enforce_keys [
    :id,
    :type,
    :status
  ]
  defstruct @enforce_keys

  @typedoc """
  Id of the peer, unique across within the room.
  """
  @type id :: String.t()

  @typedoc """
  Type of the peer.

  For more information refer to [Jellyfish documentation](https://jellyfish-dev.github.io/jellyfish-docs/).
  """
  @type type :: :webrtc

  @valid_type_strings ["webrtc"]

  @typedoc """
  Status of the peer.

  For more information refer to [Jellyfish documentation](https://jellyfish-dev.github.io/jellyfish-docs/).
  """
  @type status :: :disconnected | :connected

  @valid_status_strings ["disconnected", "connected"]

  @typedoc """
  Peer-specific options.

  For the list of available options, refer to [Jellyfish documentation](https://jellyfish-dev.github.io/jellyfish-docs/).
  """
  @type options :: WebRTC.t()

  @typedoc """
  Peer options module.
  """
  @type options_module :: WebRTC

  @typedoc """
  Stores information about the peer.
  """
  @type t :: %__MODULE__{
          id: id(),
          type: type(),
          status: status()
        }

  @doc false
  @spec from_json(map()) :: t()
  def from_json(response) do
    case response do
      %{
        "id" => id,
        "type" => type_str,
        "status" => status_str
      } ->
        %__MODULE__{
          id: id,
          type: type_from_string(type_str),
          status: status_from_string(status_str)
        }

      _other ->
        raise StructureError
    end
  end

  @doc false
  @spec type_from_options(struct()) :: type()
  def type_from_options(peer) do
    case peer do
      %WebRTC{} -> :webrtc
      _other -> raise "Invalid peer options struct"
    end
  end

  @doc false
  @spec type_from_string(String.t()) :: type()
  def type_from_string(string) do
    if string in @valid_type_strings,
      do: String.to_atom(string),
      else: raise("Invalid peer type string")
  end

  @spec status_from_string(String.t()) :: status()
  def status_from_string(string) do
    if string in @valid_status_strings,
      do: String.to_atom(string),
      else: raise("Invalid peer type string")
  end
end

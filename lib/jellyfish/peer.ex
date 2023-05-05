defmodule Jellyfish.Peer do
  @moduledoc """
  Defines `t:Jellyfish.Peer.t/0`.

  Peer is an entity that connects to the server to publish, subscribe to or publish and subscribe
  to tracks published by components and other peers.
  For more information refer to [Jellyfish documentation](https://www.membrane.stream)
  """

  alias Jellyfish.Exception.StructureError

  @enforce_keys [
    :id,
    :type
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

  @typedoc """
  Stores information about the peer.
  """
  @type t :: %__MODULE__{
          id: id(),
          type: type()
        }

  @valid_type_strings ["webrtc"]

  @doc false
  @spec from_json(map()) :: t()
  def from_json(response) do
    case response do
      %{
        "id" => id,
        "type" => type_str
      } ->
        %__MODULE__{
          id: id,
          type: type_from_string(type_str)
        }

      _other ->
        raise StructureError
    end
  end

  @doc false
  @spec type_from_string(String.t()) :: atom()
  def type_from_string(string) do
    if string in @valid_type_strings,
      do: String.to_atom(string),
      else: raise("Invalid peer type string")
  end
end

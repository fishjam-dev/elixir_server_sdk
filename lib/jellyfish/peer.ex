defmodule Jellyfish.Peer do
  @moduledoc """
  Defines `t:Jellyfish.Peer.t/0`.

  Peer is an entity that connects to the server to publish, subscribe to or publish and subscribe
  to tracks published by components and other peers.
  For more information refer to [Jellyfish documentation](https://www.membrane.stream)
  """

  alias Jellyfish.Exception.ResponseStructureError

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
  @type type :: String.t()

  @typedoc """
  Stores information about the peer.
  """
  @type t :: %__MODULE__{
          id: id(),
          type: type()
        }

  @doc false
  @spec from_json(map()) :: t()
  def from_json(response) do
    case response do
      %{
        "id" => id,
        "type" => type
      } ->
        %__MODULE__{
          id: id,
          type: type
        }

      _other ->
        raise ResponseStructureError
    end
  end
end

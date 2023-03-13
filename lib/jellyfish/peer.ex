defmodule Jellyfish.Peer do
  @moduledoc """
  Defines `t:Jellyfish.SDK.Peer.t/0`.

  Peer is an entity that connects to the server to publish, subscribe to or publish and subscribe
  to tracks published by components and other peers.
  For more information refer to [Jellyfish documentation](https://www.membrane.stream)
  """

  @enforce_keys [
    :id,
    :type
  ]
  defstruct @enforce_keys

  @typedoc """
  Id of the peer, unique across within the room.
  """
  @type id :: String.t()

  # TODO change links do docs to proper ones (here and in moduledoc)
  @typedoc """
  Type of the peer.

  For more information refer to [Jellyfish documentation](https://www.membrane.stream).
  """
  @type type :: String.t()

  @typedoc """
  Stores information about the peer.
  """
  @type t :: %__MODULE__{
          id: id(),
          type: type()
        }
end

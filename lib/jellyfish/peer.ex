defmodule Jellyfish.Peer do
  @moduledoc """
  Defines `t:Jellyfish.SDK.Peer.t/0`.
  """

  @enforce_keys [
    :id,
    :type
  ]
  defstruct @enforce_keys

  @typedoc """
  Id of a component in a form of UUID string.
  """
  @type id :: String.t()

  # TODO: use atoms instead of strings, proper link to documentation
  @typedoc """
  Type of the peer.

  For more information see [Jellyfish documentation](https://www.membrane.stream).
  """
  @type type :: String.t()

  @typedoc """
  Stores information about the peer.
  """
  @type t :: %__MODULE__{
          id: id,
          type: type
        }
end

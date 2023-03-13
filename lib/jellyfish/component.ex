defmodule Jellyfish.Component do
  @moduledoc """
  Defines `t:Jellyfish.SDK.Component.t/0`.

  Component is a server-side entity that can publish, subscribe to and process tracks.
  For more information refer to [Jellyfish documentation](https://www.membrane.stream)
  """

  @enforce_keys [
    :id,
    :type
  ]
  defstruct @enforce_keys

  @typedoc """
  Id of the component, unique within the room.
  """
  @type id :: String.t()

  # TODO change links do docs to proper ones (here and in moduledoc)
  @typedoc """
  Type of the component.

  For more information refer to [Jellyfish documentation](https://www.membrane.stream).
  """
  @type type :: String.t()

  @typedoc """
  Type describing component options.
  For the list of available options, please refer to the component's documentation.
  """
  @type options :: Keyword.t()

  @typedoc """
  Stores information about the component.
  """
  @type t :: %__MODULE__{
          id: id(),
          type: type()
        }
end

defmodule Jellyfish.Component do
  @moduledoc """
  Defines `t:Jellyfish.Component.t/0`.

  Component is a server-side entity that can publish, subscribe to and process tracks.
  For more information refer to [Jellyfish documentation](https://www.membrane.stream)
  """

  alias Jellyfish.Exception.ResponseStructureError

  @enforce_keys [
    :id,
    :type
  ]
  defstruct @enforce_keys

  @typedoc """
  Id of the component, unique within the room.
  """
  @type id :: String.t()

  @typedoc """
  Type of the component.

  For more information refer to [Jellyfish documentation](https://jellyfish-dev.github.io/jellyfish-docs/).
  """
  @type type :: String.t()

  # TODO update to proper link when it's done
  @typedoc """
  Type describing component options.
  For the list of available options, please refer to the [component's documentation](https://jellyfish-dev.github.io/jellyfish-docs/).
  """
  @type options :: Keyword.t()

  @typedoc """
  Stores information about the component.
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

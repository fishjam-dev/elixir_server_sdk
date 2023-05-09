defmodule Jellyfish.Component do
  @moduledoc """
  Defines `t:Jellyfish.Component.t/0`.

  Component is a server-side entity that can publish, subscribe to and process tracks.
  For more information refer to [Jellyfish documentation](https://www.membrane.stream)
  """

  alias Jellyfish.Component.{HLS, RTSP}
  alias Jellyfish.Exception.StructureError

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
  @type type :: :hls | :rtsp

  @typedoc """
  Component-specific options.

  For the list of available options, refer to [Jellyfish documentation](https://jellyfish-dev.github.io/jellyfish-docs/).
  """
  @type options :: HLS.t() | RTSP.t()

  @typedoc """
  Component options module.
  """
  @type options_module :: HLS | RTSP

  @typedoc """
  Stores information about the component.
  """
  @type t :: %__MODULE__{
          id: id(),
          type: type()
        }

  @valid_type_strings ["hls", "rtsp"]

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
  @spec type_from_options(struct()) :: type()
  def type_from_options(component) do
    case component do
      %HLS{} -> :hls
      %RTSP{} -> :rtsp
      _other -> raise "Invalid component options struct"
    end
  end

  @doc false
  @spec type_from_string(String.t()) :: type()
  def type_from_string(string) do
    if string in @valid_type_strings,
      do: String.to_atom(string),
      else: raise("Invalid component type string")
  end
end

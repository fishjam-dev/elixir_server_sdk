defmodule Jellyfish.Component do
  @moduledoc """
  Defines `t:Jellyfish.Component.t/0`.

  Component is a server-side entity that can publish, subscribe to and process tracks.
  For more information refer to [Jellyfish documentation](https://jellyfish-dev.github.io/jellyfish-docs/introduction/basic_concepts).
  """

  alias Jellyfish.Component.{HLS, RTSP}
  alias Jellyfish.Exception.StructureError
  alias Jellyfish.ServerMessage.SubscribeResponse.RoomState

  @enforce_keys [
    :id,
    :type,
    :metadata
  ]
  defstruct @enforce_keys

  @typedoc """
  Id of the component, unique within the room.
  """
  @type id :: String.t()

  @typedoc """
  Type of the component.
  """
  @type type :: HLS | RTSP

  @typedoc """
  Component-specific options.
  """
  @type options :: HLS.t() | RTSP.t()

  @typedoc """
  Stores information about the component.
  """
  @type t :: %__MODULE__{
          id: id(),
          type: type(),
          metadata: map()
        }

  @doc false
  @spec from_json(map()) :: t()
  def from_json(response) do
    case response do
      %{
        "id" => id,
        "type" => type_str,
        "metadata" => metadata
      } ->
        type = type_from_string(type_str)

        %__MODULE__{
          id: id,
          type: type,
          metadata: type.from_json(metadata)
        }

      _other ->
        raise StructureError
    end
  end

  @doc false
  @spec from_proto(RoomState.Component.t()) :: t()
  def from_proto(response) do
    case response do
      %RoomState.Component{
        id: id,
        component: {_type, component}
      } ->
        type = type_from_proto(component)

        %__MODULE__{
          id: id,
          type: type,
          metadata: type.from_proto(component)
        }

      _other ->
        raise StructureError
    end
  end

  @doc false
  @spec string_from_options(struct()) :: String.t()
  def string_from_options(%HLS{}), do: "hls"
  def string_from_options(%RTSP{}), do: "rtsp"

  defp type_from_string("hls"), do: HLS
  defp type_from_string("rtsp"), do: RTSP

  defp type_from_proto(%RoomState.Component.Hls{}), do: HLS
  defp type_from_proto(%RoomState.Component.Rtsp{}), do: RTSP
end

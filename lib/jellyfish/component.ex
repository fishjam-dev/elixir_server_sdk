defmodule Fishjam.Component do
  @moduledoc """
  Defines `t:Fishjam.Component.t/0`.

  Component is a server-side entity that can publish, subscribe to and process tracks.
  For more information refer to [Fishjam documentation](https://fishjam-dev.github.io/fishjam-docs/introduction/basic_concepts).
  """

  alias Fishjam.Component.{File, HLS, Recording, RTSP, SIP}
  alias Fishjam.Exception.StructureError
  alias Fishjam.Track

  @enforce_keys [
    :id,
    :type,
    :properties,
    :tracks
  ]
  defstruct @enforce_keys

  @typedoc """
  Id of the component, unique within the room.
  """
  @type id :: String.t()

  @typedoc """
  Type of the component.
  """
  @type type :: HLS | RTSP | File | SIP | Recording

  @typedoc """
  Component-specific options.
  """
  @type options :: HLS.t() | RTSP.t() | File.t() | SIP.t() | Recording.t()

  @typedoc """
  Stores information about the component.
  """
  @type t :: %__MODULE__{
          id: id(),
          type: type(),
          properties: map(),
          tracks: [Track.t()]
        }

  @doc false
  @spec from_json(map()) :: t()
  def from_json(response) do
    case response do
      %{
        "id" => id,
        "type" => type_str,
        "properties" => properties,
        "tracks" => tracks
      } ->
        type = type_from_string(type_str)

        %__MODULE__{
          id: id,
          type: type,
          properties: type.properties_from_json(properties),
          tracks: Enum.map(tracks, &Track.from_json/1)
        }

      unknown_structure ->
        raise StructureError, unknown_structure
    end
  end

  @doc false
  @spec string_from_options(struct()) :: String.t()
  def string_from_options(%File{}), do: "file"
  def string_from_options(%HLS{}), do: "hls"
  def string_from_options(%RTSP{}), do: "rtsp"
  def string_from_options(%SIP{}), do: "sip"
  def string_from_options(%Recording{}), do: "recording"

  defp type_from_string("file"), do: File
  defp type_from_string("hls"), do: HLS
  defp type_from_string("rtsp"), do: RTSP
  defp type_from_string("sip"), do: SIP
  defp type_from_string("recording"), do: Recording
end

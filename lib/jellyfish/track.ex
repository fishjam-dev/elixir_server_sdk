defmodule Jellyfish.Track do
  @moduledoc """
  Defines `t:Jellyfish.Track.t/0`.

  It represents a single media track, either audio or video.
  """

  alias Jellyfish.Exception.StructureError

  @enforce_keys [
    :id,
    :type,
    :encoding
  ]
  defstruct @enforce_keys ++ [metadata: %{}]

  @typedoc """
  Id of the track, unique within the room.
  """
  @type id :: String.t()

  @typedoc """
  Type of the track.
  """
  @type type :: :audio | :video

  @valid_type_string ["audio", "video"]

  @typedoc """
  Encoding of the track.
  """
  @type encoding :: :H264 | :VP8 | :OPUS

  @valid_encoding_strings ["H264", "VP8", "OPUS"]

  @typedoc """
  Track metadata.
  """
  @type metadata :: String.t()

  @typedoc """
  Stores information about the track.
  """
  @type t :: %__MODULE__{
          id: id(),
          type: type(),
          encoding: encoding(),
          metadata: metadata()
        }

  @doc false
  @spec from_json(map()) :: t()
  def from_json(response) do
    case response do
      %{
        "id" => id,
        "type" => type_str,
        "encoding" => encoding_str,
        "metadata" => metadata
      } ->
        %__MODULE__{
          id: id,
          type: type_from_string(type_str),
          encoding: encoding_from_string(encoding_str),
          metadata: metadata
        }

      _other ->
        raise StructureError
    end
  end

  defp type_from_string(type) when type in @valid_type_string,
    do: String.to_atom(type)

  def encoding_from_string(encoding) when encoding in @valid_encoding_strings,
    do: String.to_atom(encoding)
end

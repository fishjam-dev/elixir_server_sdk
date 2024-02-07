defmodule Jellyfish.Track do
  @moduledoc """
  Defines `t:Jellyfish.Track.t/0`.

  It represents a single media track, either audio or video.
  """

  alias Jellyfish.Exception.StructureError

  @enforce_keys [
    :id,
    :type,
    :metadata
  ]
  defstruct @enforce_keys

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
  Stores information about the track.
  """
  @type t :: %__MODULE__{
          id: id(),
          type: type(),
          metadata: any()
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
        %__MODULE__{
          id: id,
          type: type_from_string(type_str),
          metadata: metadata
        }

      _other ->
        raise StructureError
    end
  end

  defp type_from_string(type) when type in @valid_type_string,
    do: String.to_atom(type)
end

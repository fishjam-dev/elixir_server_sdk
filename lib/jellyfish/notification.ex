defmodule Jellyfish.Notification do
  @moduledoc false

  alias Jellyfish.{Component, Peer, Room, Track}
  alias Jellyfish.ServerMessage.{TrackAdded, TrackMetadataUpdated, TrackRemoved}

  defmodule RoomCreated do
    @moduledoc nil

    @enforce_keys [:room_id]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            room_id: Room.id()
          }
  end

  defmodule RoomDeleted do
    @moduledoc nil

    @enforce_keys [:room_id]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            room_id: Room.id()
          }
  end

  defmodule RoomCrashed do
    @moduledoc nil

    @enforce_keys [:room_id]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            room_id: Room.id()
          }
  end

  defmodule PeerConnected do
    @moduledoc nil

    @enforce_keys [:room_id, :peer_id]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            room_id: Room.id(),
            peer_id: Peer.id()
          }
  end

  defmodule PeerDisconnected do
    @moduledoc nil

    @enforce_keys [:room_id, :peer_id]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            room_id: Room.id(),
            peer_id: Peer.id()
          }
  end

  defmodule PeerMetadataUpdated do
    @moduledoc nil

    @enforce_keys [:room_id, :peer_id, :metadata]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            room_id: Room.id(),
            peer_id: Peer.id(),
            metadata: any()
          }
  end

  defmodule PeerCrashed do
    @moduledoc nil

    @enforce_keys [:room_id, :peer_id]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            room_id: Room.id(),
            peer_id: Peer.id()
          }
  end

  defmodule ComponentCrashed do
    @moduledoc nil

    @enforce_keys [:room_id, :component_id]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            room_id: Room.id(),
            component_id: Component.id()
          }
  end

  defmodule HlsPlayable do
    @moduledoc nil

    @enforce_keys [:room_id, :component_id]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            room_id: Room.id(),
            component_id: Component.id()
          }
  end

  defmodule HlsUploaded do
    @moduledoc nil

    @enforce_keys [:room_id]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            room_id: Room.id()
          }
  end

  defmodule HlsUploadCrashed do
    @moduledoc nil

    @enforce_keys [:room_id]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            room_id: Room.id()
          }
  end

  defmodule ComponentTrackAdded do
    @moduledoc nil

    @enforce_keys [:room_id, :component_id, :track]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            room_id: Room.id(),
            component_id: Component.id(),
            track: Track.t()
          }
  end

  defmodule ComponentTrackMetadataUpdated do
    @moduledoc nil

    @enforce_keys [:room_id, :component_id, :track]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            room_id: Room.id(),
            component_id: Component.id(),
            track: Track.t()
          }
  end

  defmodule ComponentTrackRemoved do
    @moduledoc nil

    @enforce_keys [:room_id, :component_id, :track]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            room_id: Room.id(),
            component_id: Component.id(),
            track: Track.t()
          }
  end

  defmodule PeerTrackAdded do
    @moduledoc nil

    @enforce_keys [:room_id, :peer_id, :track]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            room_id: Room.id(),
            peer_id: Peer.id(),
            track: Track.t()
          }
  end

  defmodule PeerTrackMetadataUpdated do
    @moduledoc nil

    @enforce_keys [:room_id, :peer_id, :track]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            room_id: Room.id(),
            peer_id: Peer.id(),
            track: Track.t()
          }
  end

  defmodule PeerTrackRemoved do
    @moduledoc nil

    @enforce_keys [:room_id, :peer_id, :track]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            room_id: Room.id(),
            peer_id: Peer.id(),
            track: Track.t()
          }
  end

  @discarded_fields [:__unknown_fields__]

  @doc false
  def to_notification(%module{} = message)
      when module in [TrackAdded, TrackMetadataUpdated, TrackRemoved] do
    {endpoint_type, endpoint_id} = message.endpoint_info

    notification_module =
      case {endpoint_type, module} do
        {:component_id, TrackAdded} -> ComponentTrackAdded
        {:component_id, TrackMetadataUpdated} -> ComponentTrackMetadataUpdated
        {:component_id, TrackRemoved} -> ComponentTrackRemoved
        {:peer_id, TrackAdded} -> PeerTrackAdded
        {:peer_id, TrackMetadataUpdated} -> PeerTrackMetadataUpdated
        {:peer_id, TrackRemoved} -> PeerTrackRemoved
      end

    discarded_fields = @discarded_fields ++ [:endpoint_info]

    message
    |> Map.from_struct()
    |> Map.drop(discarded_fields)
    |> Map.merge(%{
      endpoint_type => endpoint_id,
      :track => from_proto_track(message.track)
    })
    |> then(&struct!(notification_module, &1))
  end

  def to_notification(%module{} = message) do
    notification_module =
      module
      |> Module.split()
      |> List.last()
      |> then(&Module.concat(__MODULE__, &1))

    message
    |> Map.from_struct()
    |> Map.drop(@discarded_fields)
    |> then(&struct!(notification_module, &1))
  end

  defp from_proto_track(track) do
    %Track{
      id: track.id,
      type: from_proto_track_type(track.type),
      metadata: Jason.decode!(track.metadata)
    }
  end

  defp from_proto_track_type(:TRACK_TYPE_VIDEO), do: :video
  defp from_proto_track_type(:TRACK_TYPE_AUDIO), do: :audio
end

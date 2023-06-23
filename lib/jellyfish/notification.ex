defmodule Jellyfish.Notification do
  @moduledoc false

  alias Jellyfish.{Component, Peer, Room}

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

  @discarded_fields [:__unknown_fields__]

  @doc false
  def to_notification(%module{} = message) do
    notification_module =
      module
      |> Module.split()
      |> List.last()
      |> then(&Module.concat(__MODULE__, &1))

    message
    |> Map.from_struct()
    |> Enum.reject(fn {k, _v} -> k in @discarded_fields end)
    |> then(&struct!(notification_module, &1))
  end
end

defmodule Jellyfish.Notification do
  @moduledoc """
  Submodules of this module represent Jellyfish server notifications.
  See `Jellyfish.Notifier` for more information.
  """

  defmodule RoomCrashed do
    @moduledoc "Defines `t:Jellyfish.Notification.RoomCrashed.t/0`."

    @enforce_keys [:room_id]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            room_id: String.t()
          }
  end

  defmodule PeerConnected do
    @moduledoc "Defines `t:Jellyfish.Notification.PeerConnected.t/0`."

    @enforce_keys [:room_id, :peer_id]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            room_id: String.t(),
            peer_id: String.t()
          }
  end

  defmodule PeerDisconnected do
    @moduledoc "Defines `t:Jellyfish.Notification.PeerDisconnected.t/0`."

    @enforce_keys [:room_id, :peer_id]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            room_id: String.t(),
            peer_id: String.t()
          }
  end

  defmodule PeerCrashed do
    @moduledoc "Defines `t:Jellyfish.Notification.PeerCrashed.t/0`."

    @enforce_keys [:room_id, :peer_id]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            room_id: String.t(),
            peer_id: String.t()
          }
  end

  defmodule ComponentCrashed do
    @moduledoc "Defines `t:Jellyfish.Notification.ComponentCrashed.t/0`."

    @enforce_keys [:room_id, :component_id]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            room_id: String.t(),
            component_id: String.t()
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

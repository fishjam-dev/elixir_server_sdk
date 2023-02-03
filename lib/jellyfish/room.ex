defmodule Jellyfish.SDK.Room do
  @moduledoc false

  alias Tesla.Client
  alias Jellyfish.SDK.{Component, Peer}

  @enforce_keys [
    :id,
    :config,
    :components,
    :peers
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: String.t(),
          config: map(),
          components: [Component.t()],
          peers: [Peer.t()]
        }

  @spec create_room(Client.t(), non_neg_integer()) :: {:ok, t()} | {:error, String.t()}
  def create_room(client, max_peers) do
    # TODO
  end

  @spec delete_room(Client.t(), String.t()) :: :ok | {:error, String.t()}
  def delete_room(client, room_id) do
    # TODO
  end

  @spec get_rooms(Client.t()) :: {:ok, [t()]} | {:error, String.t()}
  def get_rooms(client) do
    # TODO
  end

  @spec get_room_by_id(Client.t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def get_room_by_id(client, room_id) do
    # TODO
  end
end

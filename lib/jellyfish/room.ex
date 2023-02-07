defmodule Jellyfish.SDK.Room do
  @moduledoc false

  alias Tesla.{Client, Env}
  alias Jellyfish.SDK.{Component, Peer, Utils}

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

  @spec create_room(Client.t(), non_neg_integer() | nil) :: {:ok, t()} | {:error, String.t()}
  def create_room(client, max_peers) do
    case Tesla.post(client, "/room", %{"maxPeers" => max_peers},
           headers: [{"content-type", "application/json"}]
         ) do
      {:ok, %Env{status: 201, body: body}} ->
        {:ok, room_from_json(Map.fetch!(body, "data"))}

      error ->
        Utils.translate_error_response(error)
    end
  end

  @spec delete_room(Client.t(), String.t()) :: :ok | {:error, String.t()}
  def delete_room(client, room_id) do
    case Tesla.delete(client, "/room/" <> room_id) do
      {:ok, %Env{status: 204}} -> :ok
      error -> Utils.translate_error_response(error)
    end
  end

  @spec get_rooms(Client.t()) :: {:ok, [t()]} | {:error, String.t()}
  def get_rooms(client) do
    case Tesla.get(client, "/room") do
      {:ok, %Env{status: 200, body: body}} ->
        result =
          body
          |> Map.fetch!("data")
          |> Enum.map(&room_from_json/1)

        {:ok, result}

      error ->
        Utils.translate_error_response(error)
    end
  end

  @spec get_room_by_id(Client.t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def get_room_by_id(client, room_id) do
    case Tesla.get(client, "/room/" <> room_id) do
      {:ok, %Env{status: 200, body: body}} ->
        {:ok, room_from_json(Map.fetch!(body, "data"))}

      error ->
        Utils.translate_error_response(error)
    end
  end

  @spec room_from_json(map()) :: t()
  def room_from_json(response) do
    # raises when response structure is invalid
    %{
      "id" => id,
      "config" => %{"maxPeers" => max_peers},
      "components" => components,
      "peers" => peers
    } = response

    %__MODULE__{
      id: id,
      config: %{max_peers: max_peers},
      components: Enum.map(components, &Component.component_from_json/1),
      peers: Enum.map(peers, &Peer.peer_from_json/1)
    }
  end
end

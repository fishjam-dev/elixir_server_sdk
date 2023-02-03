defmodule Jellyfish.SDK.Room do
  @moduledoc false

  alias Tesla.{Client, Env}
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
    case Tesla.post(client, "/room", %{"maxPeers" => max_peers}) do
      {:ok, %Env{status: 201, body: body}} -> room_from_json(Map.get(body, "data"))
      error -> translate_error_response(error)
    end
  end

  @spec delete_room(Client.t(), String.t()) :: :ok | {:error, String.t()}
  def delete_room(client, room_id) do
    case Tesla.delete(client, "/room/" <> room_id) do
      {:ok, %Env{status: 200}} -> :ok
      error -> translate_error_response(error)
    end
  end

  @spec get_rooms(Client.t()) :: {:ok, [t()]} | {:error, String.t()}
  def get_rooms(client) do
    case Tesla.get(client, "/room") do
      {:ok, %Env{status: 200, body: body}} ->
        rooms = Enum.map(Map.get(body, "data"), &room_from_json/1)

        if Enum.all?(rooms, &match?({:ok, _rest}, &1)) do
          {:ok, Enum.map(rooms, fn {:ok, room} -> room end)}
        else
          {:error, :invalid_body_structure}
        end

      error ->
        translate_error_response(error)
    end
  end

  @spec get_room_by_id(Client.t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def get_room_by_id(client, room_id) do
    case Tesla.get(client, "/room/" <> room_id) do
      {:ok, %Env{status: 200, body: body}} -> room_from_json(Map.get(body, "data"))
      error -> translate_error_response(error)
    end
  end

  @spec room_from_json(map()) :: {:ok, t()} | {:error, atom()}
  def room_from_json(response_body) do
    case response_body do
      %{
        "id" => id,
        "config" => config,
        "components" => components,
        "peers" => peers
      } ->
        {:ok,
         %__MODULE__{
           id: id,
           config: config,
           components: Enum.map(components, &Component.component_from_json/1),
           peers: Enum.map(peers, &Peer.peer_from_json/1)
         }}

      _other ->
        {:error, :invalid_body_structure}
    end
  end

  defp translate_error_response({:ok, %Env{body: %{"errors" => error}}}) do
    {:error, "Request failed: #{inspect(error)}"}
  end

  defp translate_error_response({:error, reason}) do
    {:error, "Internal error: #{inspect(reason)}"}
  end
end

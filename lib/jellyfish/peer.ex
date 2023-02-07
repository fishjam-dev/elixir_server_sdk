defmodule Jellyfish.SDK.Peer do
  @moduledoc false

  alias Jellyfish.SDK.Utils
  alias Tesla.{Client, Env}

  @enforce_keys [
    :id,
    :type
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: String.t(),
          type: String.t()
        }

  @spec add_peer(Client.t(), String.t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def add_peer(client, room_id, type) do
    case Tesla.post(client, "/room/" <> room_id <> "/peer", %{"type" => type},
           headers: [{"content-type", "application/json"}]
         ) do
      {:ok, %Env{status: 201, body: body}} -> {:ok, peer_from_json(Map.get(body, "data"))}
      error -> Utils.translate_error_response(error)
    end
  end

  @spec delete_peer(Client.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def delete_peer(client, room_id, peer_id) do
    case Tesla.delete(client, "/room/" <> room_id <> "/peer/" <> peer_id) do
      {:ok, %Env{status: 204}} -> :ok
      error -> Utils.translate_error_response(error)
    end
  end

  @spec peer_from_json(map()) :: t()
  def peer_from_json(response) do
    # raises when response structure is ivalid
    %{
      "id" => id,
      "type" => type
    } = response

    %__MODULE__{
      id: id,
      type: type
    }
  end
end

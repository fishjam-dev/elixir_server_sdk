defmodule Jellyfish.SDK.Peer do
  @moduledoc false

  alias Tesla.Client

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
    # TODO
  end

  @spec delete_peer(Client.t(), String.t(), String.t()) :: :ok, {:error, String.t()}
  def delete_peer(client, room_id, peer_id) do
    # TODO
  end

  @spec peer_from_json(map()) :: {:ok, t()} | {:error, atom()}
  def peer_from_json(response_body) do
    case response_body do
      %{
        "data" => %{
          "id" => id,
          "type" => type
        }
      } ->
        {:ok,
         %__MODULE__{
           id: id,
           type: type
         }}

      _other ->
        {:error, :invalid_body_structure}
    end
  end
end

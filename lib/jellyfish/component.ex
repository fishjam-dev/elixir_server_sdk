defmodule Jellyfish.SDK.Component do
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

  @spec create_component(Client.t(), String.t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def create_component(client, room_id, type) do
    # TODO
  end

  @spec delete_component(Client.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def delete_component(client, room_id, component_id) do
    # TODO
  end

  @spec component_from_json(map()) :: {:ok, t()} | {:error, atom()}
  def component_from_json(response_body) do
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

defmodule Jellyfish.SDK.Component do
  @moduledoc false

  alias Tesla.{Client, Env}
  alias Jellyfish.SDK.Utils

  @enforce_keys [
    :id,
    :type
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: String.t(),
          type: String.t()
        }

  @spec create_component(Client.t(), String.t(), String.t(), map()) ::
          {:ok, t()} | {:error, String.t()}
  def create_component(client, room_id, type, options) do
    case Tesla.post(client, "/room/" <> room_id <> "/component", %{
           "type" => type,
           "options" => options
         }) do
      {:ok, %Env{status: 201, body: body}} -> component_from_json(Map.get(body, "data"))
      error -> Utils.translate_error_response(error)
    end
  end

  @spec delete_component(Client.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def delete_component(client, room_id, component_id) do
    case Tesla.delete(client, "/room/" <> room_id <> "/component/" <> component_id) do
      {:ok, %Env{status: 204}} -> :ok
      error -> Utils.translate_error_response(error)
    end
  end

  @spec component_from_json(map()) :: t()
  def component_from_json(response) do
    # raises when response structure is invalid
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

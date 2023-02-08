defmodule Jellyfish.SDK.Component do
  @moduledoc """
  Utilities for manipulating the components.

  ## Examples
  ```
  iex> room.id
  "d3af274a-c975-4876-9e1c-4714da0249b8"

  iex> {:ok, component} = Jellyfish.SDK.Component.create_component(client, room.id, "hls")
  {:ok
    %Jellyfish.SDK.Component{
      id: "3a645faa-59d1-4f94-ae6a-83c65c695ec5",
      type: "hls"
    }
  }

  iex> :ok = Jellyfish.SDK.Component.delete_component(client, room.id, component.id)
  :ok
  ```
  """

  alias Jellyfish.SDK.{Client, Utils}
  alias Tesla.Env

  @enforce_keys [
    :id,
    :type
  ]
  defstruct @enforce_keys

  @typedoc """
  Struct that stores information about the component.

  * `id` - id (uuid) of the component
  * `type` - type of the component
  """
  @type t :: %__MODULE__{
          id: String.t(),
          type: String.t()
        }

  @doc ~S"""
  Send request to create component in specified room.

  ## Parameters

    * `client` - instance of `t:Jellyfish.SDK.Client.t/0`
    * `room_id` - id of the room that the component will be created in
    * `type` - type of the component
    * `options` - component options
  """
  @spec create_component(Client.t(), String.t(), String.t(), map()) ::
          {:ok, t()} | {:error, String.t()}
  def create_component(client, room_id, type, options) do
    case Tesla.post(
           client.http_client,
           "/room/" <> room_id <> "/component",
           %{
             "type" => type,
             "options" => options
           },
           headers: [{"content-type", "application/json"}]
         ) do
      {:ok, %Env{status: 201, body: body}} -> {:ok, component_from_json(Map.get(body, "data"))}
      error -> Utils.translate_error_response(error)
    end
  end

  @doc ~S"""
  Send request to delete component from specified room.

  ## Parameters

    * `client` - instance of `t:Jellyfish.SDK.Client.t/0`
    * `room_id` - id of the room that the component will be deleted from
    * `component_id` - id of the component that will be deleted
  """
  @spec delete_component(Client.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def delete_component(client, room_id, component_id) do
    case Tesla.delete(
           client.http_client,
           "/room/" <> room_id <> "/component/" <> component_id
         ) do
      {:ok, %Env{status: 204}} -> :ok
      error -> Utils.translate_error_response(error)
    end
  end

  @doc ~S"""
  Maps a `"data"` field of request response body from string keys to atom keys.

  Will fail if the input structure is invalid.

  ## Parameters

    * `response` - a map representing JSON response
  """
  @spec component_from_json(map()) :: t()
  def component_from_json(response) do
    # fails when response structure is invalid
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

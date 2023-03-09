defmodule Jellyfish.Client do
  @moduledoc """
  Allows to create client, then use it to create, delete or list rooms.
  One client represents one instance of Jellyfish.

  ## Examples
  ```
  iex> client = Jellyfish.Client.new("http://addresstojellyfish.com")  => %Jellyfish.Client{...}

  iex> {:ok, room} = Jellyfish.Client.create_room(client, max_peers: 10)
  {:ok,
    %Jellyfish.Room{
      components: [],
      config: %{max_peers: 10},
      id: "d3af274a-c975-4876-9e1c-4714da0249b8",
      peers: []
  }}

  iex> :ok = Jellyfish.Client.delete_room(client, room.id)
  :ok
  ```
  """

  alias Jellyfish.Exception.ResponseStructureError
  alias Jellyfish.{Room, Utils}
  alias Tesla.Env

  @enforce_keys [
    :http_client
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          http_client: Tesla.Client.t()
        }

  @doc """
  Creates new instance of `t:Jellyfish.Client.t/0`.

  ## Parameters

    * `address` - url or IP address of the Jellyfish server instance
  """
  @spec new(String.t()) :: t()
  def new(address) do
    middleware = [
      {Tesla.Middleware.BaseUrl, address},
      Tesla.Middleware.JSON
    ]

    adapter = Tesla.Adapter.Hackney
    http_client = Tesla.client(middleware, adapter)

    %__MODULE__{http_client: http_client}
  end

  @doc """
  List metadata of all of the rooms.
  """
  @spec list_rooms(t()) :: {:ok, [Room.t()]} | {:error, atom() | String.t()}
  def list_rooms(client) do
    with {:ok, %Env{status: 200, body: body}} <- Tesla.get(client.http_client, "/room"),
         {:ok, data} <- Map.fetch(body, "data"),
         result <- Enum.map(data, &Utils.room_from_json/1) do
      {:ok, result}
    else
      :error -> raise ResponseStructureError
      error -> Utils.handle_response_error(error)
    end
  end

  @doc """
  Get metadata of the room with `room_id`.
  """
  @spec get_room_by_id(t(), Room.id()) :: {:ok, Room.t()} | {:error, atom() | String.t()}
  def get_room_by_id(client, room_id) do
    with {:ok, %Env{status: 200, body: body}} <-
           Tesla.get(client.http_client, "/room/#{room_id}"),
         {:ok, data} <- Map.fetch(body, "data"),
         result <- Utils.room_from_json(data) do
      {:ok, result}
    else
      :error -> raise ResponseStructureError
      error -> Utils.handle_response_error(error)
    end
  end

  @doc """
  Create a room.
  """
  @spec create_room(t(), Room.options()) :: {:ok, Room.t()} | {:error, atom() | String.t()}
  def create_room(client, opts \\ []) do
    with {:ok, %Env{status: 201, body: body}} <-
           Tesla.post(
             client.http_client,
             "/room",
             %{"maxPeers" => Keyword.get(opts, :max_peers)},
             headers: [{"content-type", "application/json"}]
           ),
         {:ok, data} <- Map.fetch(body, "data"),
         result <- Utils.room_from_json(data) do
      {:ok, result}
    else
      :error -> raise ResponseStructureError
      error -> Utils.handle_response_error(error)
    end
  end

  @doc """
  Delete the room with `room_id`.
  """
  @spec delete_room(t(), Room.id()) :: :ok | {:error, atom() | String.t()}
  def delete_room(client, room_id) do
    case Tesla.delete(client.http_client, "/room/#{room_id}") do
      {:ok, %Env{status: 204}} -> :ok
      error -> Utils.handle_response_error(error)
    end
  end
end

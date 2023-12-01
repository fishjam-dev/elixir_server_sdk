defmodule Jellyfish.Recording do
  @moduledoc """
  Utilites for manipulating the recordings.

  ## Examples
  ```
  iex> client = Jellyfish.Client.new()
  iex> assert {:ok, []} = Jellyfish.Recording.get_list(client)
  iex> assert {:error, "Request failed: Recording not found"} = Jellyfish.Recording.delete(client, "not_exisiting_recording")
  ```
  """

  alias Jellyfish.Exception.StructureError
  alias Jellyfish.{Client, Utils}
  alias Tesla.Env

  @typedoc """
  Id for the recording, unique within Jellyfish instance.
  """
  @type id :: String.t()

  @doc """
  Lists all available recordings.
  """
  @spec get_list(Client.t()) :: {:ok, [id()]} | {:error, String.t()}
  def get_list(client) do
    with {:ok, %Env{status: 200, body: body}} <-
           Tesla.get(client.http_client, "/recording"),
         {:ok, data} <- Map.fetch(body, "data") do
      {:ok, data}
    else
      :error -> raise StructureError
      error -> Utils.handle_response_error(error)
    end
  end

  @doc """
  Deletes the recording with `id`.
  """
  @spec delete(Client.t(), id()) :: :ok | {:error, String.t()}
  def delete(client, id) do
    case Tesla.delete(
           client.http_client,
           "/recording/#{id}"
         ) do
      {:ok, %Env{status: 204}} -> :ok
      error -> Utils.handle_response_error(error)
    end
  end
end

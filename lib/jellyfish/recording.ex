defmodule Fishjam.Recording do
  @moduledoc """
  Utilites for manipulating the recordings.

  ## Examples
  ```
  iex> client = Fishjam.Client.new()
  iex> assert {:ok, []} = Fishjam.Recording.get_list(client)
  iex> assert {:error, "Request failed: Recording not found"} = Fishjam.Recording.delete(client, "not_exisiting_recording")
  ```
  """

  alias Fishjam.{Client, Utils}
  alias Tesla.Env

  @typedoc """
  Id for the recording, unique within Fishjam instance.
  """
  @type id :: String.t()

  @doc """
  Lists all available recordings.
  """
  @spec get_list(Client.t()) :: {:ok, [id()]} | {:error, String.t()}
  def get_list(client) do
    Utils.make_get_request!(client, "/recording")
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

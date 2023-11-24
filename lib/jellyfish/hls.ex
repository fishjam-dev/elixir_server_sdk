defmodule Jellyfish.HLS do
  @moduledoc """
  Utilities for manipulating the hls component.
  """

  alias Tesla.Env
  alias Jellyfish.{Client, Room, Utils}

  @type track_id :: String.t()

  @doc """
  Adds tracks to hls component
  """
  @spec subscribe(Client.t(), Room.id(), [track_id()]) :: :ok | {:error, atom() | String.t()}
  def subscribe(client, room_id, tracks) do
    with :ok <- validate_tracks(tracks),
         {:ok, %Env{status: 201}} <-
           Tesla.post(client.http_client, "/hls/#{room_id}/subscribe", %{tracks: tracks}) do
      :ok
    else
      error -> Utils.handle_response_error(error)
    end
  end

  defp validate_tracks(tracks) when is_list(tracks), do: :ok
  defp validate_tracks(_tracks), do: {:error, :tracks_validation}
end

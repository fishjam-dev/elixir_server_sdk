defmodule Jellyfish.Utils do
  @moduledoc false

  alias Jellyfish.Exception.ResponseStructureError
  alias Jellyfish.{Component, Peer, Room}
  alias Tesla.Env

  @spec handle_response_error({:ok, any()}) :: {:error, atom() | String.t()}
  def handle_response_error({:ok, %Env{body: %{"errors" => error}}}),
    do: {:error, "Request failed: #{error}"}

  def handle_response_error({:ok, %Env{body: _body}}), do: raise(ResponseStructureError)
  def handle_response_error({:error, reason}), do: {:error, reason}

  @spec room_from_json(map) :: Room.t()
  def room_from_json(response) do
    case response do
      %{
        "id" => id,
        "config" => %{"maxPeers" => max_peers},
        "components" => components,
        "peers" => peers
      } ->
        %Room{
          id: id,
          config: %{max_peers: max_peers},
          components: Enum.map(components, &component_from_json/1),
          peers: Enum.map(peers, &peer_from_json/1)
        }

      _other ->
        raise ResponseStructureError
    end
  end

  @spec peer_from_json(map) :: Peer.t()
  def peer_from_json(response) do
    case response do
      %{
        "id" => id,
        "type" => type
      } ->
        %Peer{
          id: id,
          type: type
        }

      _other ->
        raise ResponseStructureError
    end
  end

  @spec component_from_json(map) :: Component.t()
  def component_from_json(response) do
    case response do
      %{
        "id" => id,
        "type" => type
      } ->
        %Component{
          id: id,
          type: type
        }

      _other ->
        raise ResponseStructureError
    end
  end
end

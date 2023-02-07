defmodule Jellyfish.SDK.RoomTest do
  use ExUnit.Case

  import Tesla.Mock

  alias Jellyfish.SDK.{Component, Peer, Room}

  @url "http://mockurl.com"

  @component_id "mock_component_id"
  @component_type "hls"
  @peer_id "mock_peer_id"
  @peer_type "webrtc"

  @room_id "mock_room_id"

  @max_peers 10
  @max_peers_string Integer.to_string(@max_peers)

  @invalid_room_id "invalid_mock_room_id"
  @invalid_max_peers "abc"

  @error_message "Mock error message"

  setup do
    middleware = [
      {Tesla.Middleware.BaseUrl, @url},
      Tesla.Middleware.JSON
    ]

    adapter = Tesla.Mock

    %{client: Tesla.client(middleware, adapter)}
  end

  describe "Room.create_room/2" do
    setup do
      mock(fn
        %{
          method: :post,
          url: @url <> "/room",
          body: "{\"maxPeers\":" <> @max_peers_string <> "}"
        } ->
          json(%{"data" => build_room_json(true)}, status: 201)

        %{
          method: :post,
          url: @url <> "/room",
          body: "{\"maxPeers\":\"" <> @invalid_max_peers <> "\"}"
        } ->
          json(%{"errors" => @error_message}, status: 422)
      end)
    end

    test "when request is valid", %{client: client} do
      assert {:ok, room} = Room.create_room(client, @max_peers)
      assert room == build_room(true)
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: #{@error_message}"} =
               Room.create_room(client, @invalid_max_peers)
    end
  end

  describe "Room.delete_room/2" do
    setup do
      mock(fn
        %{
          method: :delete,
          url: @url <> "/room/" <> @room_id
        } ->
          text("", status: 204)

        %{
          method: :delete,
          url: @url <> "/room/" <> @invalid_room_id
        } ->
          json(%{"errors" => @error_message}, status: 404)
      end)
    end

    test "when request is valid", %{client: client} do
      assert :ok = Room.delete_room(client, @room_id)
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: #{@error_message}"} =
               Room.delete_room(client, @invalid_room_id)
    end
  end

  describe "Room.get_rooms/1" do
    setup do
      mock(fn
        %{
          method: :get,
          url: @url <> "/room"
        } ->
          json(%{"data" => [build_room_json(false)]}, status: 200)
      end)
    end

    test "when request is valid", %{client: client} do
      assert {:ok, rooms} = Room.get_rooms(client)
      assert rooms == [build_room(false)]
    end
  end

  describe "Room.get_room_by_id/2" do
    setup do
      mock(fn
        %{
          method: :get,
          url: @url <> "/room/" <> @room_id
        } ->
          json(%{"data" => build_room_json(false)}, status: 200)

        %{
          method: :get,
          url: @url <> "/room/" <> @invalid_room_id
        } ->
          json(%{"errors" => @error_message}, status: 404)
      end)
    end

    test "when request is valid", %{client: client} do
      assert {:ok, room} = Room.get_room_by_id(client, @room_id)
      assert room == build_room(false)
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: #{@error_message}"} =
               Room.get_room_by_id(client, @invalid_room_id)
    end
  end

  describe "Room.room_from_json/1" do
    test "when input is valid" do
      assert build_room(false) == Room.room_from_json(build_room_json(false))
    end

    test "when input is invalid" do
      catch_error(Room.room_from_json(%{"invalid_key" => 5}))
    end
  end

  defp build_room(empty?) do
    %Room{
      id: @room_id,
      config: %{max_peers: @max_peers},
      components:
        if(empty?, do: [], else: [%Component{id: @component_id, type: @component_type}]),
      peers: if(empty?, do: [], else: [%Peer{id: @peer_id, type: @peer_type}])
    }
  end

  defp build_room_json(empty?) do
    %{
      "id" => @room_id,
      "config" => %{"maxPeers" => @max_peers},
      "components" =>
        if(empty?, do: [], else: [%{"id" => @component_id, "type" => @component_type}]),
      "peers" => if(empty?, do: [], else: [%{"id" => @peer_id, "type" => @peer_type}])
    }
  end
end

defmodule Jellyfish.RoomTest do
  use ExUnit.Case

  import Tesla.Mock

  alias Jellyfish.{Client, Component, Peer, Room}

  @url "http://mockurl.com"
  @invalid_url "http://invalid-url.com"

  @component_id "mock_component_id"
  @component_type "hls"
  @peer_id "mock_peer_id"
  @peer_type "webrtc"

  @room_id "mock_room_id"

  @max_peers 10

  @invalid_room_id "invalid_mock_room_id"
  @invalid_max_peers "abc"

  @invalid_peer_id "invalid_peer_id"
  @invalid_peer_type "abc"

  @invalid_component_id "invalid_component_id"
  @invalid_component_type "abc"

  @error_message "Mock error message"

  setup do
    middleware = [
      {Tesla.Middleware.BaseUrl, @url},
      Tesla.Middleware.JSON
    ]

    adapter = Tesla.Mock
    http_client = Tesla.client(middleware, adapter)

    %{client: %Client{http_client: http_client}}
  end

  describe "Room.create/2" do
    setup do
      valid_body = Jason.encode!(%{"maxPeers" => @max_peers})
      invalid_body = Jason.encode!(%{"maxPeers" => @invalid_max_peers})

      mock(fn
        %{
          method: :post,
          url: "#{@url}/room",
          body: ^valid_body
        } ->
          json(%{"data" => build_room_json(true)}, status: 201)

        %{
          method: :post,
          url: "#{@url}/room",
          body: ^invalid_body
        } ->
          json(%{"errors" => @error_message}, status: 400)
      end)
    end

    test "when request is valid", %{client: client} do
      assert {:ok, room} = Room.create(client, max_peers: @max_peers)
      assert room == build_room(true)
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: #{@error_message}"} =
               Room.create(client, max_peers: @invalid_max_peers)
    end
  end

  describe "Room.delete/2" do
    setup do
      mock(fn
        %{
          method: :delete,
          url: "#{@url}/room/#{@room_id}"
        } ->
          text("", status: 204)

        %{
          method: :delete,
          url: "#{@url}/room/#{@invalid_room_id}"
        } ->
          json(%{"errors" => @error_message}, status: 404)
      end)
    end

    test "when request is valid", %{client: client} do
      assert :ok = Room.delete(client, @room_id)
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: #{@error_message}"} = Room.delete(client, @invalid_room_id)
    end
  end

  describe "Room.get_all/1" do
    setup do
      mock(fn
        %{
          method: :get,
          url: "#{@url}/room"
        } ->
          json(%{"data" => [build_room_json(false)]}, status: 200)

        %{
          method: :get,
          url: "#{@invalid_url}/room"
        } ->
          %Tesla.Env{status: 404, body: nil}
      end)
    end

    test "when request is valid", %{client: client} do
      assert {:ok, rooms} = Room.get_all(client)
      assert rooms == [build_room(false)]
    end

    test "when request is invalid" do
      middleware = [
        {Tesla.Middleware.BaseUrl, @invalid_url},
        Tesla.Middleware.JSON
      ]

      adapter = Tesla.Mock
      http_client = Tesla.client(middleware, adapter)
      invalid_client = %Client{http_client: http_client}

      assert_raise Jellyfish.Exception.ResponseStructureError, fn ->
        Room.get_all(invalid_client)
      end
    end
  end

  describe "Room.get/2" do
    setup do
      mock(fn
        %{
          method: :get,
          url: "#{@url}/room/#{@room_id}"
        } ->
          json(%{"data" => build_room_json(false)}, status: 200)

        %{
          method: :get,
          url: "#{@url}/room/#{@invalid_room_id}"
        } ->
          json(%{"errors" => @error_message}, status: 404)
      end)
    end

    test "when request is valid", %{client: client} do
      assert {:ok, room} = Room.get(client, @room_id)
      assert room == build_room(false)
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: #{@error_message}"} = Room.get(client, @invalid_room_id)
    end
  end

  describe "Room.add_component/4" do
    setup do
      valid_body = Jason.encode!(%{"options" => %{}, "type" => @component_type})
      invalid_body = Jason.encode!(%{"options" => %{}, "type" => @invalid_component_type})

      mock(fn
        %{
          method: :post,
          url: "#{@url}/room/#{@room_id}/component",
          body: ^valid_body
        } ->
          json(%{"data" => build_component_json()}, status: 201)

        %{
          method: :post,
          url: "#{@url}/room/#{@room_id}/component",
          body: ^invalid_body
        } ->
          json(%{"errors" => @error_message}, status: 400)
      end)
    end

    test "when request is valid", %{client: client} do
      assert {:ok, component} = Room.add_component(client, @room_id, @component_type)
      assert component == build_component()
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: #{@error_message}"} =
               Room.add_component(client, @room_id, @invalid_component_type)
    end
  end

  describe "Room.delete_component/3" do
    setup do
      mock(fn
        %{
          method: :delete,
          url: "#{@url}/room/#{@room_id}/component/#{@component_id}"
        } ->
          text("", status: 204)

        %{
          method: :delete,
          url: "#{@url}/room/#{@room_id}/component/#{@invalid_component_id}"
        } ->
          json(%{"errors" => @error_message}, status: 404)
      end)
    end

    test "when request is valid", %{client: client} do
      assert :ok = Room.delete_component(client, @room_id, @component_id)
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: #{@error_message}"} =
               Room.delete_component(client, @room_id, @invalid_component_id)
    end
  end

  describe "Room.add_peer/3" do
    setup do
      valid_body = Jason.encode!(%{"type" => @peer_type})
      invalid_body = Jason.encode!(%{"type" => @invalid_peer_type})

      mock(fn
        %{
          method: :post,
          url: "#{@url}/room/#{@room_id}/peer",
          body: ^valid_body
        } ->
          json(%{"data" => build_peer_json()}, status: 201)

        %{
          method: :post,
          url: "#{@url}/room/#{@room_id}/peer",
          body: ^invalid_body
        } ->
          json(%{"errors" => @error_message}, status: 400)
      end)
    end

    test "when request is valid", %{client: client} do
      assert {:ok, peer} = Room.add_peer(client, @room_id, @peer_type)
      assert peer == build_peer()
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: #{@error_message}"} =
               Room.add_peer(client, @room_id, @invalid_peer_type)
    end
  end

  describe "Room.delete_peer/3" do
    setup do
      mock(fn
        %{
          method: :delete,
          url: "#{@url}/room/#{@room_id}/peer/#{@peer_id}"
        } ->
          text("", status: 204)

        %{
          method: :delete,
          url: "#{@url}/room/#{@room_id}/peer/#{@invalid_peer_id}"
        } ->
          json(%{"errors" => @error_message}, status: 404)
      end)
    end

    test "when request is valid", %{client: client} do
      assert :ok = Room.delete_peer(client, @room_id, @peer_id)
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: #{@error_message}"} =
               Room.delete_peer(client, @room_id, @invalid_peer_id)
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

  defp build_component() do
    %Component{id: @component_id, type: @component_type}
  end

  defp build_component_json() do
    %{"id" => @component_id, "type" => @component_type}
  end

  defp build_peer() do
    %Peer{id: @peer_id, type: @peer_type}
  end

  defp build_peer_json() do
    %{"id" => @peer_id, "type" => @peer_type, "unexpectedKey" => "value"}
  end
end

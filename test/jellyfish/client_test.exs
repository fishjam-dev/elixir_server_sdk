defmodule Jellyfish.ClientTest do
  use ExUnit.Case

  import Tesla.Mock

  alias Jellyfish.{Client, Component, Peer, Room}

  @url "https://somemockurl.com"
  @invalid_url "http://invalid-url.com"

  @component_id "mock_component_id"
  @component_type "hls"
  @peer_id "mock_peer_id"
  @peer_type "webrtc"

  @room_id "mock_room_id"

  @max_peers 10

  @invalid_room_id "invalid_mock_room_id"
  @invalid_max_peers "abc"

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

  describe "Client.new/1" do
    test "when address is valid" do
      client = Client.new(@url)

      assert %Client{
               http_client: %Tesla.Client{
                 adapter: {Tesla.Adapter.Hackney, :call, [[]]},
                 pre: [
                   {Tesla.Middleware.BaseUrl, :call, [@url]},
                   {Tesla.Middleware.JSON, :call, [[]]}
                 ]
               }
             } = client
    end
  end

  describe "Client.create_room/2" do
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
      assert {:ok, room} = Client.create_room(client, max_peers: @max_peers)
      assert room == build_room(true)
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: #{@error_message}"} =
               Client.create_room(client, max_peers: @invalid_max_peers)
    end
  end

  describe "Client.delete_room/2" do
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
      assert :ok = Client.delete_room(client, @room_id)
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: #{@error_message}"} =
               Client.delete_room(client, @invalid_room_id)
    end
  end

  describe "Client.list_rooms/1" do
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
      assert {:ok, rooms} = Client.list_rooms(client)
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
        Client.list_rooms(invalid_client)
      end
    end
  end

  describe "Client.get_room_by_id/2" do
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
      assert {:ok, room} = Client.get_room_by_id(client, @room_id)
      assert room == build_room(false)
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: #{@error_message}"} =
               Client.get_room_by_id(client, @invalid_room_id)
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

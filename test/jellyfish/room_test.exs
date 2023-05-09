defmodule Jellyfish.RoomTest do
  use ExUnit.Case

  import Tesla.Mock

  alias Jellyfish.{Client, Component, Peer, Room}

  @server_api_token "testtoken"

  @url "mockurl.com"
  @invalid_url "invalid-url.com"

  @component_id "mock_component_id"
  @component_type :hls
  @component_opts %Component.HLS{}
  @component_opts_module Component.HLS
  @peer_id "mock_peer_id"
  @peer_type :webrtc
  @peer_opts %Peer.WebRTC{}
  @peer_opts_module Peer.WebRTC

  @room_id "mock_room_id"

  @max_peers 10

  @invalid_room_id "invalid_mock_room_id"
  @invalid_max_peers "abc"

  @invalid_peer_id "invalid_peer_id"
  defmodule InvalidPeerOpts do
    defstruct [:qwe, :rty]
  end

  @invalid_component_id "invalid_component_id"
  defmodule InvalidComponentOpts do
    defstruct [:abc, :def]
  end

  @error_message "Mock error message"

  setup do
    current_adapter = Application.get_env(:jellyfish_server_sdk, :tesla_adapter)

    Application.put_env(:jellyfish_server_sdk, :tesla_adapter, Tesla.Mock)

    on_exit(fn ->
      if current_adapter == nil do
        Application.delete_env(:jellyfish_server_sdk, :tesla_adapter)
      else
        Application.put_env(:jellyfish_server_sdk, :tesla_adapter, current_adapter)
      end
    end)

    %{client: Client.new(server_address: @url, server_api_token: @server_api_token)}
  end

  describe "auth" do
    setup do
      valid_body = Jason.encode!(%{"maxPeers" => @max_peers})

      mock(fn %{
                method: :post,
                url: "http://#{@url}/room",
                body: ^valid_body
              } = env ->
        case Tesla.get_header(env, "authorization") do
          "Bearer " <> @server_api_token ->
            json(%{"data" => build_room_json(true)}, status: 201)

          "Bearer " <> _other ->
            json(%{"errors" => "Invalid token"}, status: 401)
        end
      end)
    end

    test "correct token", %{client: client} do
      assert {:ok, room} = Room.create(client, max_peers: @max_peers)
      assert room == build_room(true)
    end

    test "invalid token" do
      client = Client.new(server_address: @url, server_api_token: "invalid" <> @server_api_token)
      assert {:error, _reason} = Room.create(client, max_peers: @max_peers)
    end
  end

  describe "Room.create/2" do
    setup do
      valid_body = Jason.encode!(%{"maxPeers" => @max_peers})
      invalid_body = Jason.encode!(%{"maxPeers" => @invalid_max_peers})

      mock(fn
        %{
          method: :post,
          url: "http://#{@url}/room",
          body: ^valid_body
        } ->
          json(%{"data" => build_room_json(true)}, status: 201)

        %{
          method: :post,
          url: "http://#{@url}/room",
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
          url: "http://#{@url}/room/#{@room_id}"
        } ->
          text("", status: 204)

        %{
          method: :delete,
          url: "http://#{@url}/room/#{@invalid_room_id}"
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
          url: "http://#{@url}/room"
        } ->
          json(%{"data" => [build_room_json(false)]}, status: 200)

        %{
          method: :get,
          url: "http://#{@invalid_url}/room"
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
        {Tesla.Middleware.BaseUrl, "http://#{@invalid_url}"},
        Tesla.Middleware.JSON
      ]

      adapter = Tesla.Mock
      http_client = Tesla.client(middleware, adapter)
      invalid_client = %Client{http_client: http_client}

      assert_raise Jellyfish.Exception.StructureError, fn ->
        Room.get_all(invalid_client)
      end
    end
  end

  describe "Room.get/2" do
    setup do
      mock(fn
        %{
          method: :get,
          url: "http://#{@url}/room/#{@room_id}"
        } ->
          json(%{"data" => build_room_json(false)}, status: 200)

        %{
          method: :get,
          url: "http://#{@url}/room/#{@invalid_room_id}"
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

  describe "Room.add_component/3" do
    setup do
      valid_body = Jason.encode!(%{"options" => %{}, "type" => @component_type})

      mock(fn
        %{
          method: :post,
          url: "http://#{@url}/room/#{@room_id}/component",
          body: ^valid_body
        } ->
          json(%{"data" => build_component_json()}, status: 201)
      end)
    end

    test "when request is valid", %{client: client} do
      assert {:ok, component} = Room.add_component(client, @room_id, @component_opts)
      assert component == build_component()

      assert {:ok, component} = Room.add_component(client, @room_id, @component_opts_module)
      assert component == build_component()
    end

    test "when request is invalid", %{client: client} do
      assert_raise RuntimeError, ~r/invalid.*options/i, fn ->
        Room.add_component(client, @room_id, %InvalidComponentOpts{})
      end

      assert_raise RuntimeError, ~r/invalid.*options/i, fn ->
        Room.add_component(client, @room_id, InvalidComponentOpts)
      end
    end
  end

  describe "Room.delete_component/3" do
    setup do
      mock(fn
        %{
          method: :delete,
          url: "http://#{@url}/room/#{@room_id}/component/#{@component_id}"
        } ->
          text("", status: 204)

        %{
          method: :delete,
          url: "http://#{@url}/room/#{@room_id}/component/#{@invalid_component_id}"
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

      mock(fn
        %{
          method: :post,
          url: "http://#{@url}/room/#{@room_id}/peer",
          body: ^valid_body
        } ->
          json(%{"data" => build_peer_json()}, status: 201)
      end)
    end

    test "when request is valid", %{client: client} do
      assert {:ok, peer, _peer_token} = Room.add_peer(client, @room_id, @peer_opts)
      assert peer == build_peer()

      assert {:ok, peer, _peer_token} = Room.add_peer(client, @room_id, @peer_opts_module)
      assert peer == build_peer()
    end

    test "when request is invalid", %{client: client} do
      assert_raise RuntimeError, ~r/invalid.*options/i, fn ->
        Room.add_peer(client, @room_id, %InvalidPeerOpts{})
      end

      assert_raise RuntimeError, ~r/invalid.*options/i, fn ->
        Room.add_peer(client, @room_id, InvalidPeerOpts)
      end
    end
  end

  describe "Room.delete_peer/3" do
    setup do
      mock(fn
        %{
          method: :delete,
          url: "http://#{@url}/room/#{@room_id}/peer/#{@peer_id}"
        } ->
          text("", status: 204)

        %{
          method: :delete,
          url: "http://#{@url}/room/#{@room_id}/peer/#{@invalid_peer_id}"
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
    %{peer: %{"id" => @peer_id, "type" => @peer_type}, token: "token"}
  end
end

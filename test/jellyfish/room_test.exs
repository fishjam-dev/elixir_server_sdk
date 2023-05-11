defmodule Jellyfish.RoomTest do
  use ExUnit.Case

  import Tesla.Mock

  alias Jellyfish.{Client, Component, Peer, Room}

  @server_api_token "development"

  @url "localhost:5002"
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

  setup do
    current_adapter = Application.get_env(:jellyfish_server_sdk, :tesla_adapter)

    %{client: Client.new(server_address: @url, server_api_token: @server_api_token)}
  end

  describe "auth" do
    test "correct token", %{client: client} do
      assert {:ok, room} = Room.create(client, max_peers: @max_peers)

      assert %Jellyfish.Room{
               components: [],
               config: %{max_peers: 10},
               id: _id,
               peers: []
             } = room
    end

    test "invalid token" do
      client = Client.new(server_address: @url, server_api_token: "invalid" <> @server_api_token)
      assert {:error, _reason} = Room.create(client, max_peers: @max_peers)
    end
  end

  describe "Room.create/2" do
    test "when request is valid", %{client: client} do
      assert {:ok, room} = Room.create(client, max_peers: @max_peers)

      assert %Jellyfish.Room{
               components: [],
               config: %{max_peers: 10},
               id: _id,
               peers: []
             } = room
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: maxPeers must be a number"} =
               Room.create(client, max_peers: @invalid_max_peers)
    end
  end

  describe "Room.delete/2" do
    setup [:create_room]

    test "when request is valid", %{client: client, room_id: room_id} do
      assert :ok = Room.delete(client, room_id)
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: Room #{@invalid_room_id} doest not exist"} =
               Room.delete(client, @invalid_room_id)
    end
  end

  describe "Room.get_all/1" do
    setup [:create_room]

    test "when request is valid", %{client: client, room_id: room_id} do
      assert {:ok, rooms} = Room.get_all(client)
      assert Enum.any?(rooms, &(&1.id == room_id))
    end
  end

  describe "Room.get/2" do
    setup [:create_room]

    test "when request is valid", %{client: client, room_id: room_id} do
      assert {:ok,
              %Jellyfish.Room{
                components: [],
                config: %{max_peers: @max_peers},
                id: ^room_id,
                peers: []
              }} = Room.get(client, room_id)
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: Room invalid_mock_room_id does not exist"} =
               Room.get(client, @invalid_room_id)
    end
  end

  describe "Room.add_component/3" do
    setup [:create_room]

    test "when request is valid", %{client: client, room_id: room_id} do
      assert {:ok, component} = Room.add_component(client, room_id, @component_opts)
      assert %Jellyfish.Component{type: :hls} = component

      assert {:ok, component} = Room.add_component(client, room_id, @component_opts_module)
      assert %Jellyfish.Component{type: :hls} = component
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
    setup [:create_room, :create_component]

    test "when request is valid", %{client: client, room_id: room_id, component_id: component_id} do
      assert :ok = Room.delete_component(client, room_id, component_id)
    end

    test "when request is invalid", %{client: client, room_id: room_id} do
      assert {:error, "Request failed: Component #{@invalid_component_id} does not exist"} =
               Room.delete_component(client, room_id, @invalid_component_id)
    end
  end

  describe "Room.add_peer/3" do
    setup [:create_room]

    test "when request is valid", %{client: client, room_id: room_id} do
      assert {:ok, peer, _peer_token} = Room.add_peer(client, room_id, @peer_opts)
      assert %Jellyfish.Peer{type: :webrtc} = peer

      assert {:ok, peer, _peer_token} = Room.add_peer(client, room_id, @peer_opts_module)
      assert %Jellyfish.Peer{type: :webrtc} = peer
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
    setup [:create_room, :create_peer]

    test "when request is valid", %{client: client, room_id: room_id, peer_id: peer_id} do
      assert :ok = Room.delete_peer(client, room_id, peer_id)
    end

    test "when request is invalid", %{client: client, room_id: room_id} do
      assert {:error, "Request failed: Peer #{@invalid_peer_id} does not exist"} =
               Room.delete_peer(client, room_id, @invalid_peer_id)
    end
  end

  defp create_room(state) do
    assert {:ok, %Jellyfish.Room{id: id}} = Room.create(state.client, max_peers: @max_peers)

    %{room_id: id}
  end

  defp create_peer(state) do
    assert {:ok, %Jellyfish.Peer{id: id}, _token} =
             Room.add_peer(state.client, state.room_id, @peer_opts)

    %{peer_id: id}
  end

  defp create_component(state) do
    assert {:ok, %Jellyfish.Component{id: id}} =
             Room.add_component(state.client, state.room_id, @component_opts)

    %{component_id: id}
  end
end

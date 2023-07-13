defmodule Jellyfish.NotifierTest do
  use ExUnit.Case

  alias Jellyfish.Notification.RoomDeleted
  alias Jellyfish.{Client, Notifier, Peer, Room}

  alias Jellyfish.PeerMessage
  alias Jellyfish.PeerMessage.AuthRequest

  alias Jellyfish.Notification.{
    PeerConnected,
    PeerDisconnected,
    RoomCreated,
    RoomDeleted
  }

  alias Jellyfish.WS

  @peer_opts %Peer.WebRTC{}

  @max_peers 10

  describe "connecting to the server and subcribing for events" do
    test "when credentials are valid" do
      assert {:ok, pid} = Notifier.start_link()
      assert is_pid(pid)
    end

    test "when token is invalid" do
      assert {:error, :invalid_token} = Notifier.start_link(server_api_token: "invalid_token")
    end
  end

  describe "subscribing for server notifications" do
    setup do
      {:ok, notifier} = Notifier.start_link()

      on_exit(fn -> Process.exit(notifier, :normal) end)

      %{
        client: Client.new(),
        notifier: notifier
      }
    end

    test "returns error if room does not exist", %{notifier: notifier} do
      assert {:error, :room_not_found} =
               Notifier.subscribe(notifier, :server_notification, "fake_room_id")
    end

    test "returns initial state of the room", %{client: client, notifier: notifier} do
      {:ok, %Jellyfish.Room{id: room_id}} = Room.create(client)
      {:ok, %Jellyfish.Peer{id: peer_id}, _token} = Room.add_peer(client, room_id, Peer.WebRTC)

      assert {:ok, %Room{id: ^room_id, peers: [%Peer{id: ^peer_id}]}} =
               Notifier.subscribe(notifier, :server_notification, room_id)
    end

    test "for all notifications", %{client: client, notifier: notifier} do
      {:ok, %Jellyfish.Room{id: room_id}} = Room.create(client)

      trigger_notification(client, room_id)
      refute_receive {:jellyfish, _msg}, 100

      assert {:ok, _rooms} = Notifier.subscribe(notifier, :server_notification, :all)

      trigger_notification(client, room_id)
      assert_receive {:jellyfish, %PeerConnected{room_id: ^room_id}}

      # different room
      {:ok, %Jellyfish.Room{id: other_room_id}} = Room.create(client)
      trigger_notification(client, other_room_id)
      assert_receive {:jellyfish, %PeerConnected{room_id: ^other_room_id}}
    end

    test "for specific room notifications only", %{client: client, notifier: notifier} do
      {:ok, %Jellyfish.Room{id: room_id}} = Room.create(client)

      assert {:ok, _room} = Notifier.subscribe(notifier, :server_notification, room_id)
      trigger_notification(client, room_id)
      assert_receive {:jellyfish, %PeerConnected{room_id: ^room_id}}

      {:ok, %Jellyfish.Room{id: other_room_id}} = Room.create(client)
      trigger_notification(client, other_room_id)
      refute_receive {:jellyfish, _msg}, 100
    end
  end

  describe "receiving notifications" do
    setup do
      {:ok, notifier} = Notifier.start_link()
      {:ok, _rooms} = Notifier.subscribe(notifier, :server_notification, :all)

      %{client: Client.new()}
    end

    test "when room gets created and then deleted", %{client: client} do
      {:ok, %Jellyfish.Room{id: room_id}} = Room.create(client, max_peers: @max_peers)

      assert_receive {:jellyfish, %RoomCreated{room_id: ^room_id}}

      :ok = Room.delete(client, room_id)

      assert_receive {:jellyfish, %RoomDeleted{room_id: ^room_id}}
    end

    test "when peer connects and then disconnects", %{client: client} do
      {:ok, %Jellyfish.Room{id: room_id}} = Room.create(client, max_peers: @max_peers)

      {:ok, %Jellyfish.Peer{id: peer_id}, peer_token} = Room.add_peer(client, room_id, @peer_opts)

      url = Application.fetch_env!(:jellyfish_server_sdk, :server_address)

      {:ok, peer_ws} = WS.start_link("ws://#{url}/socket/peer/websocket")

      auth_request = %PeerMessage{content: {:auth_request, %AuthRequest{token: peer_token}}}

      :ok = WS.send_frame(peer_ws, auth_request)

      assert_receive {:jellyfish, %PeerConnected{peer_id: ^peer_id, room_id: ^room_id}}

      :ok = Room.delete_peer(client, room_id, peer_id)

      assert_receive {:jellyfish, %PeerDisconnected{peer_id: ^peer_id, room_id: ^room_id}}
    end
  end

  defp trigger_notification(client, room_id) do
    {:ok, %Jellyfish.Peer{}, peer_token} = Room.add_peer(client, room_id, @peer_opts)

    address = Application.fetch_env!(:jellyfish_server_sdk, :server_address)
    {:ok, peer_ws} = WS.start_link("ws://#{address}/socket/peer/websocket")

    auth_request = %PeerMessage{content: {:auth_request, %AuthRequest{token: peer_token}}}
    :ok = WS.send_frame(peer_ws, auth_request)
  end
end

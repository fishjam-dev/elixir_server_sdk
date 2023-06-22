defmodule Jellyfish.NotifierTest do
  use ExUnit.Case

  alias Jellyfish.{Client, Notifier, Peer, Room}

  alias Jellyfish.PeerMessage
  alias Jellyfish.PeerMessage.AuthRequest

  alias Jellyfish.Notification.{
    PeerConnected,
    PeerDisconnected
  }

  alias Jellyfish.WS

  @peer_opts %Peer.WebRTC{}

  @max_peers 10

  describe "connecting to the server" do
    test "when credentials are valid" do
      assert {:ok, pid} = Notifier.start_link()
      assert is_pid(pid)
    end

    test "when token is invalid" do
      assert {:error, :invalid_token} = Notifier.start_link(server_api_token: "invalid_token")
    end
  end

  describe "subscribing" do
    setup do
      {:ok, notifier} = Notifier.start_link()

      on_exit(fn -> Notifier.unsubscribe(notifier) end)

      %{
        client: Client.new(),
        notifier: notifier
      }
    end

    test "for all notifications", %{client: client, notifier: notifier} do
      {:ok, %Jellyfish.Room{id: room_id}} = Room.create(client)

      trigger_notification(client, room_id)
      refute_receive {:jellyfish, _msg}, 100

      Notifier.subscribe(notifier, :all)

      trigger_notification(client, room_id)
      assert_receive {:jellyfish, %PeerConnected{room_id: ^room_id}}

      # different room
      {:ok, %Jellyfish.Room{id: other_room_id}} = Room.create(client)
      trigger_notification(client, other_room_id)
      assert_receive {:jellyfish, %PeerConnected{room_id: ^other_room_id}}
    end

    test "for specific room notifications only", %{client: client, notifier: notifier} do
      {:ok, %Jellyfish.Room{id: room_id}} = Room.create(client)

      Notifier.subscribe(notifier, room_id)
      trigger_notification(client, room_id)
      assert_receive {:jellyfish, %PeerConnected{room_id: ^room_id}}

      {:ok, %Jellyfish.Room{id: other_room_id}} = Room.create(client)
      trigger_notification(client, other_room_id)
      refute_receive {:jellyfish, _msg}, 100
    end

    test "and later unsubscribing", %{client: client, notifier: notifier} do
      {:ok, %Jellyfish.Room{id: room_id}} = Room.create(client)

      Notifier.subscribe(notifier, :all)
      trigger_notification(client, room_id)
      assert_receive {:jellyfish, %PeerConnected{room_id: ^room_id}}

      Notifier.unsubscribe(notifier)
      trigger_notification(client, room_id)
      refute_receive {:jellyfish, _msg}, 100
    end
  end

  describe "receiving notifications" do
    setup do
      {:ok, notifier} = Notifier.start_link()
      :ok = Notifier.subscribe(notifier, :all)

      %{client: Client.new()}
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

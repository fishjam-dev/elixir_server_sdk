defmodule Jellyfish.NotifierTest do
  use ExUnit.Case

  alias Jellyfish.{Client, Notifier, Peer, Room}

  alias Jellyfish.PeerMessage
  alias Jellyfish.PeerMessage.AuthRequest

  alias Jellyfish.Notification.{
    PeerConnected,
    PeerDisconnected,
    RoomCreated,
    RoomDeleted
  }

  alias Jellyfish.MetricsReport

  alias Jellyfish.WS
  alias Phoenix.PubSub

  @peer_opts %Peer.WebRTC{}

  @max_peers 10
  @video_codec :vp8
  @webhook_port 4000
  @webhook_url "http://172.28.0.2:#{@webhook_port}/"
  @pubsub Jellyfish.PubSub

  setup_all do
    children = [
      {Plug.Cowboy,
       plug: WebHookPlug, scheme: :http, options: [port: @webhook_port, ip: {0, 0, 0, 0}]},
      {Phoenix.PubSub, name: Jellyfish.PubSub}
    ]

    {:ok, _pid} =
      Supervisor.start_link(children,
        strategy: :one_for_one
      )

    :ok
  end

  setup do
    :ok = PubSub.subscribe(@pubsub, "webhook")

    on_exit(fn ->
      :ok = PubSub.unsubscribe(@pubsub, "webhook")
    end)
  end

  describe "connecting to the server and subcribing for events" do
    test "when credentials are valid" do
      assert {:ok, pid} = Notifier.start_link()
      assert is_pid(pid)
    end

    test "when token is invalid" do
      assert {:error, :invalid_token} = Notifier.start_link(server_api_token: "invalid_token")
    end
  end

  describe "receiving notifications" do
    setup do
      {:ok, notifier} = Notifier.start_link()
      :ok = Notifier.subscribe_server_notifications(notifier)

      %{client: Client.new()}
    end

    test "when room gets created and then deleted", %{client: client} do
      {:ok, %Jellyfish.Room{id: room_id}, _jellyfish_address} =
        Room.create(client,
          max_peers: @max_peers,
          video_codec: @video_codec,
          webhook_url: @webhook_url
        )

      assert_receive {:jellyfish, %RoomCreated{room_id: ^room_id}}
      assert_receive %RoomCreated{room_id: ^room_id}, 2_500

      :ok = Room.delete(client, room_id)

      assert_receive {:jellyfish, %RoomDeleted{room_id: ^room_id}}
      assert_receive %RoomDeleted{room_id: ^room_id}, 2_500
    end

    test "when peer connects and then disconnects", %{client: client} do
      {:ok, %Jellyfish.Room{id: room_id}, jellyfish_address} =
        Room.create(client,
          max_peers: @max_peers,
          video_codec: @video_codec,
          webhook_url: @webhook_url
        )

      {:ok, %Jellyfish.Peer{id: peer_id}, peer_token} = Room.add_peer(client, room_id, @peer_opts)

      {:ok, peer_ws} = WS.start_link("ws://#{jellyfish_address}/socket/peer/websocket")

      auth_request = %PeerMessage{content: {:auth_request, %AuthRequest{token: peer_token}}}

      :ok = WS.send_frame(peer_ws, auth_request)

      assert_receive {:jellyfish, %PeerConnected{peer_id: ^peer_id, room_id: ^room_id}}
      assert_receive %PeerConnected{peer_id: ^peer_id, room_id: ^room_id}, 2_500

      :ok = Room.delete_peer(client, room_id, peer_id)

      assert_receive {:jellyfish, %PeerDisconnected{peer_id: ^peer_id, room_id: ^room_id}}, 1_000
      assert_receive %PeerDisconnected{peer_id: ^peer_id, room_id: ^room_id}, 2_500
    end
  end

  describe "receiving metrics" do
    setup do
      {:ok, notifier} = Notifier.start_link()
      :ok = Notifier.subscribe_server_notifications(notifier)
      :ok = Notifier.subscribe_metrics(notifier)

      %{client: Client.new()}
    end

    test "with one peer", %{client: client} do
      {:ok, %Jellyfish.Room{id: room_id}, jellyfish_address} =
        Room.create(client,
          max_peers: @max_peers,
          webhook_url: @webhook_url
        )

      {:ok, %Jellyfish.Peer{id: peer_id}, peer_token} = Room.add_peer(client, room_id, @peer_opts)

      {:ok, peer_ws} = WS.start_link("ws://#{jellyfish_address}/socket/peer/websocket")

      auth_request = %PeerMessage{content: {:auth_request, %AuthRequest{token: peer_token}}}
      :ok = WS.send_frame(peer_ws, auth_request)

      assert_receive {:jellyfish, %PeerConnected{peer_id: ^peer_id, room_id: ^room_id}}
      assert_receive %PeerConnected{peer_id: ^peer_id, room_id: ^room_id}, 2_500

      assert_receive {:jellyfish, %MetricsReport{metrics: metrics}} when metrics != %{}, 1500
    end
  end
end

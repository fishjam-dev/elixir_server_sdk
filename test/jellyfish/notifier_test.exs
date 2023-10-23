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

    webhook_address =
      System.get_env(
        "WEBHOOK_ADDRESS",
        Application.fetch_env!(:jellyfish_server_sdk, :webhook_address)
      )

    webhook_address = "http://#{webhook_address}:#{@webhook_port}/"

    server_address =
      System.get_env(
        "SERVER_ADDRESS",
        Application.fetch_env!(:jellyfish_server_sdk, :server_address)
      )

    {:ok, %{webhook_address: webhook_address, server_address: server_address}}
  end

  describe "connecting to the server and subcribing for events" do
    test "when credentials are valid", %{server_address: server_address} do
      assert {:ok, pid} = Notifier.start_link(server_address: server_address)
      assert is_pid(pid)
    end

    test "when token is invalid", %{server_address: server_address} do
      assert {:error, :invalid_token} =
               Notifier.start_link(
                 server_api_token: "invalid_token",
                 server_address: server_address
               )
    end
  end

  describe "receiving notifications" do
    setup %{server_address: server_address, webhook_address: webhook_address} do
      {:ok, notifier} = Notifier.start_link(server_address: server_address)
      :ok = Notifier.subscribe_server_notifications(notifier)

      %{client: Client.new(server_address: server_address), webhook_address: webhook_address}
    end

    test "when room gets created and then deleted", %{
      client: client,
      webhook_address: webhook_address
    } do
      {:ok, %Jellyfish.Room{id: room_id}, _jellyfish_address} =
        Room.create(client,
          max_peers: @max_peers,
          video_codec: @video_codec,
          webhook_url: webhook_address
        )

      assert_receive {:jellyfish, %RoomCreated{room_id: ^room_id}}
      assert_receive {:webhook, %RoomCreated{room_id: ^room_id}}, 2_500

      :ok = Room.delete(client, room_id)

      assert_receive {:jellyfish, %RoomDeleted{room_id: ^room_id}}
      assert_receive {:webhook, %RoomDeleted{room_id: ^room_id}}, 2_500
    end

    test "when peer connects and then disconnects", %{
      client: client,
      webhook_address: webhook_address
    } do
      {:ok, %Jellyfish.Room{id: room_id}, jellyfish_address} =
        Room.create(client,
          max_peers: @max_peers,
          video_codec: @video_codec,
          webhook_url: webhook_address
        )

      {:ok, %Jellyfish.Peer{id: peer_id}, peer_token} = Room.add_peer(client, room_id, @peer_opts)

      {:ok, peer_ws} = WS.start_link("ws://#{jellyfish_address}/socket/peer/websocket")

      auth_request = %PeerMessage{content: {:auth_request, %AuthRequest{token: peer_token}}}

      :ok = WS.send_frame(peer_ws, auth_request)

      assert_receive {:jellyfish, %PeerConnected{peer_id: ^peer_id, room_id: ^room_id}}
      assert_receive {:webhook, %PeerConnected{peer_id: ^peer_id, room_id: ^room_id}}, 2_500

      :ok = Room.delete_peer(client, room_id, peer_id)

      assert_receive {:jellyfish, %PeerDisconnected{peer_id: ^peer_id, room_id: ^room_id}}, 1_000
      assert_receive {:webhook, %PeerDisconnected{peer_id: ^peer_id, room_id: ^room_id}}, 2_500
    end
  end

  describe "receiving metrics" do
    setup %{server_address: server_address, webhook_address: webhook_address} do
      {:ok, notifier} = Notifier.start_link(server_address: server_address)
      :ok = Notifier.subscribe_server_notifications(notifier)
      :ok = Notifier.subscribe_metrics(notifier)

      %{client: Client.new(server_address: server_address), webhook_address: webhook_address}
    end

    test "with one peer", %{client: client, webhook_address: webhook_address} do
      {:ok, %Jellyfish.Room{id: room_id}, jellyfish_address} =
        Room.create(client,
          max_peers: @max_peers,
          webhook_url: webhook_address
        )

      {:ok, %Jellyfish.Peer{id: peer_id}, peer_token} = Room.add_peer(client, room_id, @peer_opts)

      {:ok, peer_ws} = WS.start_link("ws://#{jellyfish_address}/socket/peer/websocket")

      auth_request = %PeerMessage{content: {:auth_request, %AuthRequest{token: peer_token}}}
      :ok = WS.send_frame(peer_ws, auth_request)

      assert_receive {:jellyfish, %PeerConnected{peer_id: ^peer_id, room_id: ^room_id}}
      assert_receive {:webhook, %PeerConnected{peer_id: ^peer_id, room_id: ^room_id}}, 2_500

      assert_receive {:jellyfish, %MetricsReport{metrics: metrics}} when metrics != %{}, 1500
    end
  end
end

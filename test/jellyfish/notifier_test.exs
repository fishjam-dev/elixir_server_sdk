defmodule Fishjam.NotifierTest do
  use ExUnit.Case
  doctest Fishjam.WebhookNotifier
  alias Fishjam.{Client, Component, Peer, Room, Track, WSNotifier}
  alias Fishjam.Component.File

  alias Fishjam.PeerMessage
  alias Fishjam.PeerMessage.AuthRequest

  alias Fishjam.Notification.{
    ComponentTrackAdded,
    ComponentTrackRemoved,
    PeerAdded,
    PeerConnected,
    PeerDeleted,
    PeerDisconnected,
    PeerMetadataUpdated,
    RoomCreated,
    RoomDeleted
  }

  alias Fishjam.MetricsReport

  alias Fishjam.WS
  alias Phoenix.PubSub

  @peer_opts %Peer.WebRTC{}

  @file_component_opts %File{
    file_path: "video.h264"
  }

  @max_peers 10
  @video_codec :vp8
  @peerless_purge_timeout_s 1
  @peer_disconnected_timeout_s 1
  @webhook_port 4000
  @webhook_host Application.compile_env!(:fishjam_server_sdk, :webhook_address)
  @webhook_address "http://#{@webhook_host}:#{@webhook_port}/"
  @pubsub Fishjam.PubSub

  setup_all do
    children = [
      {Plug.Cowboy,
       plug: WebHookPlug, scheme: :http, options: [port: @webhook_port, ip: {0, 0, 0, 0}]},
      {Phoenix.PubSub, name: Fishjam.PubSub}
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
    test "when credentials are valid", %{} do
      assert {:ok, pid} = WSNotifier.start_link()
      assert is_pid(pid)
    end

    test "when token is invalid", %{} do
      assert {:error, :invalid_token} = WSNotifier.start_link(server_api_token: "invalid_token")
    end
  end

  describe "receiving notifications" do
    setup do
      {:ok, notifier} = WSNotifier.start_link()
      :ok = WSNotifier.subscribe_server_notifications(notifier)

      %{client: Client.new()}
    end

    test "when room gets created and then deleted", %{
      client: client
    } do
      {:ok, %Fishjam.Room{id: room_id}, _fishjam_address} =
        Room.create(client,
          max_peers: @max_peers,
          video_codec: @video_codec,
          webhook_url: @webhook_address
        )

      assert_receive {:fishjam, %RoomCreated{room_id: ^room_id}}
      assert_receive {:webhook, %RoomCreated{room_id: ^room_id}}, 2_500

      :ok = Room.delete(client, room_id)

      assert_receive {:fishjam, %RoomDeleted{room_id: ^room_id}}
      assert_receive {:webhook, %RoomDeleted{room_id: ^room_id}}, 2_500
    end

    test "when peer connects, updates metadata and then disconnects", %{
      client: client
    } do
      {room_id, peer_id, peer_ws} = create_room_and_auth_ws(client)

      assert_receive {:fishjam,
                      %PeerConnected{peer_id: ^peer_id, room_id: ^room_id} = peer_connected}

      assert_receive {:webhook, ^peer_connected}, 2_500

      metadata = %{name: "GelatinGenius"}
      metadata_encoded = Jason.encode!(metadata)

      media_event = %PeerMessage{
        content:
          {:media_event,
           %PeerMessage.MediaEvent{
             data: %{"type" => "connect", "data" => %{"metadata" => metadata}} |> Jason.encode!()
           }}
      }

      :ok = WS.send_frame(peer_ws, media_event)

      assert_receive {:fishjam,
                      %PeerMetadataUpdated{
                        peer_id: ^peer_id,
                        room_id: ^room_id,
                        metadata: ^metadata_encoded
                      } = peer_metadata_updated},
                     2000

      assert_receive {:webhook, ^peer_metadata_updated}, 2_500

      :ok = Room.delete_peer(client, room_id, peer_id)

      assert_receive {:fishjam,
                      %PeerDisconnected{peer_id: ^peer_id, room_id: ^room_id} = peer_disconnected},
                     1_000

      assert_receive {:webhook, ^peer_disconnected}, 2_500

      :ok = Room.delete(client, room_id)
    end

    test "when peer connects and then disconnects peer is removed with timeout", %{
      client: client
    } do
      {:ok, %Fishjam.Room{id: room_id}, fishjam_address} =
        Room.create(client,
          max_peers: @max_peers,
          video_codec: @video_codec,
          webhook_url: @webhook_address,
          peerless_purge_timeout: @peerless_purge_timeout_s,
          peer_disconnected_timeout_s: @peer_disconnected_timeout_s
        )

      {:ok, %{peer: %Fishjam.Peer{id: peer_id}, token: peer_token}} =
        Room.add_peer(client, room_id, @peer_opts)

      assert_receive {:fishjam, %PeerAdded{peer_id: ^peer_id, room_id: ^room_id} = peer_added},
                     1_000

      assert_receive {:webhook, ^peer_added}, 2_500

      {:ok, peer_ws} = WS.start_link("ws://#{fishjam_address}/socket/peer/websocket")

      auth_request = %PeerMessage{content: {:auth_request, %AuthRequest{token: peer_token}}}
      :ok = WS.send_frame(peer_ws, auth_request)
      {room_id, peer_id, peer_ws}

      assert_receive {:fishjam,
                      %PeerConnected{peer_id: ^peer_id, room_id: ^room_id} = peer_connected}

      assert_receive {:webhook, ^peer_connected}, 2_500

      GenServer.stop(peer_ws)

      assert_receive {:fishjam,
                      %PeerDisconnected{peer_id: ^peer_id, room_id: ^room_id} = peer_disconnected},
                     1_000

      assert_receive {:webhook, ^peer_disconnected}, 2_500

      assert_receive {:fishjam,
                      %PeerDeleted{peer_id: ^peer_id, room_id: ^room_id} = peer_deleted},
                     2_500

      assert_receive {:webhook, ^peer_deleted}, 2_500

      assert_receive {:fishjam, %RoomDeleted{room_id: ^room_id} = room_deleted},
                     2_500

      assert_receive {:webhook, ^room_deleted}, 2_500
    end

    @tag :file_component_sources
    test "TrackAdded and TrackRemoved are sent when adding and removing FileComponent", %{
      client: client
    } do
      {room_id, _peer_id, _peer_ws} = create_room_and_auth_ws(client, video_codec: :h264)

      {:ok, %Component{id: component_id}} =
        Room.add_component(client, room_id, @file_component_opts)

      assert_receive {:fishjam,
                      %ComponentTrackAdded{
                        room_id: ^room_id,
                        component_id: ^component_id,
                        track: %Track{id: _track_id, type: :video, metadata: nil} = track
                      } = component_track_added},
                     500

      assert_receive {:webhook, ^component_track_added}

      :ok = Room.delete_component(client, room_id, component_id)

      assert_receive {:fishjam,
                      %ComponentTrackRemoved{
                        room_id: ^room_id,
                        component_id: ^component_id,
                        track: ^track
                      } = component_track_removed},
                     1000

      assert_receive {:webhook, ^component_track_removed}

      :ok = Room.delete(client, room_id)
    end
  end

  describe "receiving metrics" do
    setup do
      {:ok, notifier} = WSNotifier.start_link()
      :ok = WSNotifier.subscribe_server_notifications(notifier)
      :ok = WSNotifier.subscribe_metrics(notifier)

      %{client: Client.new()}
    end

    test "with one peer", %{client: client} do
      {room_id, peer_id, _peer_ws} = create_room_and_auth_ws(client)

      assert_receive {:fishjam, %PeerConnected{peer_id: ^peer_id, room_id: ^room_id}}
      assert_receive {:webhook, %PeerConnected{peer_id: ^peer_id, room_id: ^room_id}}, 2_500

      assert_receive {:fishjam, %MetricsReport{metrics: metrics}} when metrics != %{}, 1500

      :ok = Room.delete(client, room_id)
    end
  end

  defp create_room_and_auth_ws(client, room_opts \\ []) do
    {:ok, %Fishjam.Room{id: room_id}, _fishjam_address} =
      Room.create(client,
        max_peers: Keyword.get(room_opts, :max_peers, @max_peers),
        video_codec: Keyword.get(room_opts, :video_codec, @video_codec),
        webhook_url: Keyword.get(room_opts, :webhook_url, @webhook_address)
      )

    {:ok, %{peer: %Fishjam.Peer{id: peer_id}, token: peer_token, ws_url: peer_ws_url}} =
      Room.add_peer(client, room_id, @peer_opts)

    assert_receive {:fishjam, %PeerAdded{peer_id: ^peer_id, room_id: ^room_id} = peer_added},
                   1_000

    assert_receive {:webhook, ^peer_added}, 2_500

    {:ok, peer_ws} = WS.start_link("ws://#{peer_ws_url}")

    auth_request = %PeerMessage{content: {:auth_request, %AuthRequest{token: peer_token}}}
    :ok = WS.send_frame(peer_ws, auth_request)
    {room_id, peer_id, peer_ws}
  end
end

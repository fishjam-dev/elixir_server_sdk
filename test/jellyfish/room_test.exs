defmodule Jellyfish.RoomTest do
  use ExUnit.Case
  doctest Jellyfish.Room
  alias Jellyfish.Exception.OptionsError
  alias Jellyfish.{Client, Component, Peer, Room}

  @server_api_token "development"

  @hls_component_opts %Component.HLS{}
  @hls_component_opts_module Component.HLS
  @hls_properties %{
    playable: false,
    low_latency: false,
    persistent: false,
    target_window_duration: nil,
    subscribe_mode: "auto"
  }

  @s3 %{
    access_key_id: "access_key_id",
    secret_access_key: "secret_access_key",
    region: "region",
    bucket: "bucket"
  }

  @rtsp_component_opts %Component.RTSP{
    source_uri: "rtsp://ef36c6dff23ecc5bbe311cc880d95dc8.se:2137/does/not/matter"
  }

  @file_component_opts %Component.File{
    file_path: "video.h264"
  }

  @fixtures_path "test/fixtures"
  @video_filename "video.h264"

  @peer_opts %Peer.WebRTC{
    enable_simulcast: false
  }
  @peer_opts_module Peer.WebRTC

  @room_id "mock_room_id"

  @max_peers 10
  @video_codec :h264

  @invalid_room_id "invalid_mock_room_id"
  @invalid_max_peers "abc"
  @invalid_video_codec :opus

  @tracks ["track-id"]
  @invalid_tracks %{id: "track-id"}

  @invalid_peer_id "invalid_peer_id"
  defmodule InvalidPeerOpts do
    defstruct [:qwe, :rty]
  end

  @invalid_component_id "invalid_component_id"
  defmodule InvalidComponentOpts do
    defstruct [:abc, :def]
  end

  setup do
    %{client: Client.new()}
  end

  describe "auth" do
    test "correct token", %{client: client} do
      assert {:ok, room, jellyfish_address} =
               Room.create(client, max_peers: @max_peers, video_codec: @video_codec)

      assert %Jellyfish.Room{
               components: [],
               config: %{max_peers: 10, video_codec: @video_codec},
               id: _id,
               peers: []
             } = room

      server_address = Application.fetch_env!(:jellyfish_server_sdk, :server_address)

      assert ^server_address = jellyfish_address
    end

    test "invalid token" do
      client = Client.new(server_api_token: "invalid" <> @server_api_token)
      assert {:error, _reason} = Room.create(client, max_peers: @max_peers)
    end
  end

  describe "Room.create/2" do
    test "when request is valid", %{client: client} do
      assert {:ok, room, jellyfish_address} = Room.create(client, max_peers: @max_peers)

      assert %Jellyfish.Room{
               components: [],
               config: %{max_peers: 10},
               id: _id,
               peers: []
             } = room

      server_address = Application.fetch_env!(:jellyfish_server_sdk, :server_address)

      assert ^server_address = jellyfish_address
    end

    test "when request is invalid, max peers", %{client: client} do
      assert {:error, "Request failed: Expected maxPeers to be a number, got: abc"} =
               Room.create(client, max_peers: @invalid_max_peers)
    end

    test "when request is invalid, video codec", %{client: client} do
      assert {:error, "Request failed: Expected videoCodec to be 'h264' or 'vp8', got: opus"} =
               Room.create(client, video_codec: @invalid_video_codec)
    end
  end

  describe "Room.delete/2" do
    setup [:create_room]

    test "when request is valid", %{client: client, room_id: room_id} do
      assert :ok = Room.delete(client, room_id)
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: Room #{@invalid_room_id} does not exist"} =
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
    setup [:create_room, :create_component_hls]

    test "when request is valid", %{client: client, room_id: room_id, component_id: component_id} do
      assert {:ok,
              %Jellyfish.Room{
                components: [component],
                config: %{max_peers: @max_peers, video_codec: @video_codec},
                id: ^room_id,
                peers: []
              }} = Room.get(client, room_id)

      assert %Component{id: ^component_id, type: Component.HLS, properties: %{playable: false}} =
               component
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: Room invalid_mock_room_id does not exist"} =
               Room.get(client, @invalid_room_id)
    end
  end

  describe "Room.add_component/3" do
    setup [:create_room]

    test "when request is valid with opts", %{client: client, room_id: room_id} do
      assert {:ok, component} = Room.add_component(client, room_id, @hls_component_opts)
      assert %Component{type: Component.HLS, properties: @hls_properties} = component

      assert {:ok, component} = Room.add_component(client, room_id, @rtsp_component_opts)
      assert %Component{type: Component.RTSP, properties: %{}} = component

      assert {:ok, component} = Room.add_component(client, room_id, @file_component_opts)
      assert %Component{type: Component.File, properties: %{}} = component
    end

    test "HLS when request is valid with opts module", %{client: client, room_id: room_id} do
      assert {:ok, component} = Room.add_component(client, room_id, @hls_component_opts_module)
      assert %Component{type: Component.HLS, properties: @hls_properties} = component
    end

    test "HLS when request is valid with s3 credentials", %{client: client, room_id: room_id} do
      assert {:ok, component} =
               Room.add_component(client, room_id, %{@hls_component_opts | s3: @s3})

      assert %Component{type: Component.HLS, properties: @hls_properties} = component
    end

    test "HLS when request is invalid - wrong s3 credentials", %{client: client, room_id: room_id} do
      assert_raise OptionsError, fn ->
        Room.add_component(client, room_id, %{
          @hls_component_opts
          | s3: Map.delete(@s3, :bucket)
        })
      end

      assert_raise OptionsError, fn ->
        Room.add_component(client, room_id, %{@hls_component_opts | s3: []})
      end
    end

    test "HLS when request is valid with manual subscribe mode", %{
      client: client,
      room_id: room_id
    } do
      assert {:ok, component} =
               Room.add_component(client, room_id, %{
                 @hls_component_opts
                 | subscribe_mode: :manual
               })

      hls_properties = %{@hls_properties | subscribe_mode: "manual"}
      assert %Component{type: Component.HLS, properties: ^hls_properties} = component
    end

    test "HLS when request is invalid - wrong subscribe mode", %{client: client, room_id: room_id} do
      assert_raise OptionsError, fn ->
        Room.add_component(client, room_id, %{@hls_component_opts | subscribe_mode: :wrong_mode})
      end
    end

    test "HLS when request is invalid", %{client: client} do
      assert_raise OptionsError, fn ->
        Room.add_component(client, @room_id, %InvalidComponentOpts{})
      end

      assert_raise OptionsError, fn ->
        Room.add_component(client, @room_id, InvalidComponentOpts)
      end
    end

    test "File when request - video", %{client: client, room_id: room_id} do
      assert {:ok, component} =
               Room.add_component(client, room_id, %Component.File{
                 file_path: @video_filename
               })

      assert %Component{type: Component.File, properties: %{}} = component
    end

    test "File when request is invalid - invalid path", %{client: client, room_id: room_id} do
      assert {:error, "Request failed: Invalid request body structure"} =
               Room.add_component(client, room_id, %Component.File{
                 file_path: "../video.h264"
               })
    end

    test "File when request is invalid - file does not exist",
         %{client: client, room_id: room_id} do
      assert {:error, "Request failed: Invalid request body structure"} =
               Room.add_component(client, room_id, %Component.File{
                 file_path: "no_such_video.h264"
               })
    end
  end

  describe "Room.delete_component/3" do
    setup [:create_room, :create_component_hls]

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
      assert %Jellyfish.Peer{type: Peer.WebRTC} = peer

      assert {:ok, peer, _peer_token} = Room.add_peer(client, room_id, @peer_opts_module)
      assert %Jellyfish.Peer{type: Peer.WebRTC} = peer
    end

    test "when request is invalid", %{client: client} do
      assert_raise FunctionClauseError, fn ->
        Room.add_peer(client, @room_id, %InvalidPeerOpts{})
      end

      assert_raise FunctionClauseError, fn ->
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

  describe "Room.hls_subscribe/3" do
    setup [:create_room]

    test "when request is valid", %{client: client, room_id: room_id} do
      assert {:ok, %Component{properties: %{subscribe_mode: "manual"}}} =
               Room.add_component(client, room_id, %Component.HLS{subscribe_mode: :manual})

      assert :ok = Room.hls_subscribe(client, room_id, @tracks)
    end

    test "when room doesn't exist", %{client: client} do
      assert {:error, "Request failed: Room #{@invalid_room_id} does not exist"} =
               Room.hls_subscribe(client, @invalid_room_id, @tracks)
    end

    test "when hls component doesn't exist", %{client: client, room_id: room_id} do
      assert {:error, "Request failed: HLS component does not exist"} =
               Room.hls_subscribe(client, room_id, @tracks)
    end

    test "when hls component has subscribe mode :auto", %{client: client, room_id: room_id} do
      assert {:ok, %Component{properties: %{subscribe_mode: "auto"}}} =
               Room.add_component(client, room_id, %Jellyfish.Component.HLS{subscribe_mode: :auto})

      assert {:error, "Request failed: HLS component option `subscribe_mode` is set to :auto"} =
               Room.hls_subscribe(client, room_id, @tracks)
    end

    test "when request is invalid", %{client: client, room_id: room_id} do
      assert {:ok, %Component{properties: %{subscribe_mode: "manual"}}} =
               Room.add_component(client, room_id, %Component.HLS{subscribe_mode: :manual})

      assert {:error, :tracks_validation} = Room.hls_subscribe(client, room_id, @invalid_tracks)
    end
  end

  defp create_room(state) do
    assert {:ok, %Jellyfish.Room{id: id}, _jellyfish_address} =
             Room.create(state.client, max_peers: @max_peers, video_codec: @video_codec)

    %{room_id: id}
  end

  defp create_peer(state) do
    assert {:ok, %Jellyfish.Peer{id: id}, _token} =
             Room.add_peer(state.client, state.room_id, @peer_opts)

    %{peer_id: id}
  end

  defp create_component_hls(state) do
    assert {:ok, %Jellyfish.Component{id: id}} =
             Room.add_component(state.client, state.room_id, @hls_component_opts)

    %{component_id: id}
  end
end

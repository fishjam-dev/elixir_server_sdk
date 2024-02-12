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
  @rtsp_properties %{
    source_uri: "rtsp://ef36c6dff23ecc5bbe311cc880d95dc8.se:2137/does/not/matter",
    rtp_port: 20_000,
    reconnect_delay: 15_000,
    keep_alive_interval: 15_000,
    pierce_nat: true
  }

  @sip_component_opts %Component.SIP{
    registrar_credentials: %{
      address: "my-sip-registrar.net",
      username: "user-name",
      password: "pass-word"
    }
  }
  @sip_properties %{
    registrar_credentials: %{
      address: "my-sip-registrar.net",
      username: "user-name",
      password: "pass-word"
    }
  }

  @sip_phone_number "1234"

  @file_component_opts %Component.File{
    file_path: "video.h264"
  }
  @file_properties %{
    file_path: "video.h264",
    framerate: 30
  }

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

  @origins ["peer-id", "rtsp-id", "file-id"]
  @invalid_origins %{id: "peer-id"}

  @invalid_peer_id "invalid_peer_id"
  defmodule InvalidPeerOpts do
    defstruct [:qwe, :rty]
  end

  @invalid_component_id "invalid_component_id"
  defmodule InvalidComponentOpts do
    defstruct [:abc, :def]
  end

  setup_all do
    client = Client.new()

    on_exit(fn ->
      {:ok, rooms} = Room.get_all(client)

      Enum.each(rooms, fn room ->
        :ok = Room.delete(client, room.id)
      end)
    end)
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

    test "when request is valid with room_id", %{client: client} do
      room_id = UUID.uuid4()
      assert {:ok, room, jellyfish_address} = Room.create(client, room_id: room_id)

      assert %Jellyfish.Room{
               components: [],
               config: %{video_codec: nil, max_peers: nil},
               id: ^room_id,
               peers: []
             } = room

      server_address = Application.fetch_env!(:jellyfish_server_sdk, :server_address)

      assert ^server_address = jellyfish_address
    end

    test "when request is invalid, room already exists", %{client: client} do
      room_id = UUID.uuid4()
      assert {:ok, _room, _jellyfish_address} = Room.create(client, room_id: room_id)

      error_msg = "Request failed: Cannot add room with id \"#{room_id}\" - room already exists"
      assert {:error, ^error_msg} = Room.create(client, room_id: room_id)
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

    test "when request is valid with opts - hls", %{client: client, room_id: room_id} do
      assert {:ok, component} = Room.add_component(client, room_id, @hls_component_opts)
      assert %Component{type: Component.HLS, properties: @hls_properties} = component
    end

    test "when request is valid with opts - rtsp", %{client: client, room_id: room_id} do
      assert {:ok, component} = Room.add_component(client, room_id, @rtsp_component_opts)
      assert %Component{type: Component.RTSP, properties: @rtsp_properties} = component
    end

    test "when request is valid with opts - sip", %{client: client, room_id: room_id} do
      assert {:ok, component} = Room.add_component(client, room_id, @sip_component_opts)
      assert %Component{type: Component.SIP, properties: @sip_properties} = component
    end

    @tag :file_component_sources
    test "when request is valid with opts - file", %{client: client, room_id: room_id} do
      assert {:ok, component} = Room.add_component(client, room_id, @file_component_opts)
      assert %Component{type: Component.File, properties: @file_properties} = component
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

    @tag :file_component_sources
    test "File when request - video", %{client: client, room_id: room_id} do
      assert {:ok, component} =
               Room.add_component(client, room_id, %Component.File{
                 file_path: @video_filename
               })

      assert %Component{type: Component.File, properties: @file_properties} = component
    end

    @tag :file_component_sources
    test "File when request - video with different framerate", %{client: client, room_id: room_id} do
      assert {:ok, component} =
               Room.add_component(client, room_id, %Component.File{
                 file_path: @video_filename,
                 framerate: 20
               })

      new_properties = %{@file_properties | framerate: 20}

      assert %Component{type: Component.File, properties: ^new_properties} = component
    end

    test "File when request is invalid - invalid path", %{client: client, room_id: room_id} do
      assert {:error, "Request failed: Invalid file path"} =
               Room.add_component(client, room_id, %Component.File{
                 file_path: "../video.h264"
               })
    end

    test "File when request is invalid - file does not exist",
         %{client: client, room_id: room_id} do
      assert {:error, "Request failed: File not found"} =
               Room.add_component(client, room_id, %Component.File{
                 file_path: "no_such_video.h264"
               })
    end

    test "File when request is invalid - invalid framerate",
         %{client: client, room_id: room_id} do
      assert {:error, "Request failed: Invalid framerate passed"} =
               Room.add_component(client, room_id, %Component.File{
                 file_path: "video.h264",
                 framerate: -20
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

    test "when request is invalid, too many peers", %{client: client} do
      {:ok, %Jellyfish.Room{id: room_id}, _jellyfish_address} =
        Room.create(client, max_peers: 1, video_codec: @video_codec)

      assert {:ok, _peer, _peer_token} = Room.add_peer(client, room_id, @peer_opts)

      error_msg = "Request failed: Reached peer limit in room #{room_id}"

      assert {:error, ^error_msg} =
               Room.add_peer(client, room_id, @peer_opts)
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

      assert :ok = Room.hls_subscribe(client, room_id, @origins)
    end

    test "when room doesn't exist", %{client: client} do
      assert {:error, "Request failed: Room #{@invalid_room_id} does not exist"} =
               Room.hls_subscribe(client, @invalid_room_id, @origins)
    end

    test "when hls component doesn't exist", %{client: client, room_id: room_id} do
      assert {:error, "Request failed: HLS component does not exist"} =
               Room.hls_subscribe(client, room_id, @origins)
    end

    test "when hls component has subscribe mode :auto", %{client: client, room_id: room_id} do
      assert {:ok, %Component{properties: %{subscribe_mode: "auto"}}} =
               Room.add_component(client, room_id, %Jellyfish.Component.HLS{subscribe_mode: :auto})

      assert {:error, "Request failed: HLS component option `subscribe_mode` is set to :auto"} =
               Room.hls_subscribe(client, room_id, @origins)
    end

    test "when request is invalid", %{client: client, room_id: room_id} do
      assert {:ok, %Component{properties: %{subscribe_mode: "manual"}}} =
               Room.add_component(client, room_id, %Component.HLS{subscribe_mode: :manual})

      assert {:error, :origins_validation} = Room.hls_subscribe(client, room_id, @invalid_origins)
    end
  end

  describe "Room.dial/4" do
    setup [:create_room]

    test "when request is valid", %{client: client, room_id: room_id} do
      assert {:ok, %Component{id: component_id, properties: @sip_properties}} =
               Room.add_component(client, room_id, struct!(Component.SIP, @sip_component_opts))

      assert :ok = Room.dial(client, room_id, component_id, @sip_phone_number)
    end

    test "when room doesn't exist", %{client: client} do
      assert {:error, "Request failed: Room #{@invalid_room_id} does not exist"} =
               Room.dial(client, @invalid_room_id, @invalid_component_id, @sip_phone_number)
    end

    test "when provided sip component doesn't exist", %{client: client, room_id: room_id} do
      assert {:error, "Request failed: SIP component does not exist"} =
               Room.dial(client, room_id, @invalid_component_id, @sip_phone_number)
    end

    test "when provided component is different type than sip", %{client: client, room_id: room_id} do
      assert {:ok, %{id: component_id}} =
               Room.add_component(client, room_id, @rtsp_component_opts)

      assert {:error, "Request failed: SIP component does not exist"} =
               Room.dial(client, room_id, component_id, @sip_phone_number)
    end

    test "when request is invalid", %{client: client, room_id: room_id} do
      assert {:ok, %Component{id: component_id, properties: @sip_properties}} =
               Room.add_component(client, room_id, struct!(Component.SIP, @sip_component_opts))

      assert :ok = Room.dial(client, room_id, component_id, 1234)
    end
  end

  describe "Room.end_call/3" do
    setup [:create_room]

    test "when request is valid", %{client: client, room_id: room_id} do
      assert {:ok, %Component{id: component_id, properties: @sip_properties}} =
               Room.add_component(client, room_id, struct!(Component.SIP, @sip_component_opts))

      assert :ok = Room.dial(client, room_id, component_id, @sip_phone_number)

      assert :ok = Room.end_call(client, room_id, component_id)
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

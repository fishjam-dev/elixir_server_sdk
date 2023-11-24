defmodule Jellyfish.HLSTest do
  use ExUnit.Case

  alias Jellyfish.{Client, Component, HLS, Room}

  @max_peers 10
  @video_codec :h264

  @valid_tracks ["track-id"]
  @invalid_tracks %{id: "track-id"}
  @wrong_room_id "wrong-id"

  setup do
    client = Client.new()

    {:ok, %Jellyfish.Room{id: id}, _jellyfish_address} =
      Room.create(client, max_peers: @max_peers, video_codec: @video_codec)

    %{client: client, room_id: id}
  end

  describe "HLS.subscribe/3" do
    test "when request is valid", %{client: client, room_id: room_id} do
      assert {:ok, %Component{metadata: %{subscribe_mode: "manual"}}} =
               Room.add_component(client, room_id, %Component.HLS{subscribe_mode: :manual})

      assert :ok = HLS.subscribe(client, room_id, @valid_tracks)
    end

    test "when room doesn't exist", %{client: client} do
      assert {:error, "Request failed: Room #{@wrong_room_id} does not exist"} =
               HLS.subscribe(client, @wrong_room_id, @valid_tracks)
    end

    test "when hls component doesn't exist", %{client: client, room_id: room_id} do
      assert {:error, "Request failed: HLS component does not exist"} =
               HLS.subscribe(client, room_id, @valid_tracks)
    end

    test "when hls component has subscribe mode :auto", %{client: client, room_id: room_id} do
      assert {:ok, %Component{metadata: %{subscribe_mode: "auto"}}} =
               Room.add_component(client, room_id, %Jellyfish.Component.HLS{subscribe_mode: :auto})

      assert {:error, "Request failed: HLS component option `subscribe_mode` is set to :auto"} =
               HLS.subscribe(client, room_id, @valid_tracks)
    end

    test "when request is invalid", %{client: client, room_id: room_id} do
      assert {:ok, %Component{metadata: %{subscribe_mode: "manual"}}} =
               Room.add_component(client, room_id, %Component.HLS{subscribe_mode: :manual})

      assert {:error, :tracks_validation} = HLS.subscribe(client, room_id, @invalid_tracks)
    end
  end
end

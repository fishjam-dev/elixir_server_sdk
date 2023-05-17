defmodule Jellyfish.NotifierTest do
  use ExUnit.Case

  alias Jellyfish.{Client, Peer, Room}

  alias Jellyfish.Server.ControlMessage.{
    PeerConnected,
    PeerDisconnected
  }

  alias Jellyfish.WS

  @server_api_token "development"

  @url if Mix.env() == :integration_test, do: "jellyfish:5002", else: "localhost:5002"

  @peer_opts %Peer.WebRTC{}

  @max_peers 10

  @server_api_token "development"
  defmodule InvalidPeerOpts do
    defstruct [:qwe, :rty]
  end

  setup do
    {:ok, notifier_pid} =
      Jellyfish.Notifier.start(
        server_address: @url,
        server_api_token: @server_api_token
      )

    %{
      client: Client.new(server_address: @url, server_api_token: @server_api_token),
      notifier_pid: notifier_pid
    }
  end

  describe "peer notifications" do
    test "peer connects and then disconnects", %{client: client} do
      {:ok, %Jellyfish.Room{id: room_id}} = Room.create(client, max_peers: @max_peers)

      {:ok, %Jellyfish.Peer{id: peer_id}, peer_token} = Room.add_peer(client, room_id, @peer_opts)

      {:ok, peer_ws} = WS.start_link("ws://#{@url}/socket/peer/websocket")

      auth_request = %{
        "type" => "controlMessage",
        "data" => %{"type" => "authRequest", "token" => peer_token}
      }

      :ok = WS.send_frame(peer_ws, auth_request)

      assert_receive {:jellyfish, %PeerConnected{peer_id: ^peer_id, room_id: ^room_id}}

      :ok = Room.delete_peer(client, room_id, peer_id)

      assert_receive {:jellyfish, %PeerDisconnected{peer_id: ^peer_id, room_id: ^room_id}}
    end
  end
end

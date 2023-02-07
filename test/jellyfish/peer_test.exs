defmodule Jellyfish.SDK.PeerTest do
  use ExUnit.Case

  import Tesla.Mock

  alias Jellyfish.SDK.Peer

  @url "http://mockurl.com"

  @peer_id "mock_peer_id"
  @peer_type "webrtc"

  @room_id "mock_room_id"

  @invalid_peer_id "invalid_peer_id"
  @invalid_peer_type "abc"

  @error_message "Error message"

  setup do
    middleware = [
      {Tesla.Middleware.BaseUrl, @url},
      Tesla.Middleware.JSON
    ]

    adapter = Tesla.Mock

    %{client: Tesla.client(middleware, adapter)}
  end

  describe "Peer.add_peer/3" do
    setup do
      mock(fn
        %{
          method: :post,
          url: @url <> "/room/" <> @room_id <> "/peer",
          body: "{\"type\":\"" <> @peer_type <> "\"}"
        } ->
          json(%{"data" => build_peer_json()}, status: 201)

        %{
          method: :post,
          url: @url <> "/room/" <> @room_id <> "/peer",
          body: "{\"type\":\"" <> @invalid_peer_type <> "\"}"
        } ->
          json(%{"errors" => @error_message}, status: 400)
      end)
    end

    test "when request is valid", %{client: client} do
      assert {:ok, peer} = Peer.add_peer(client, @room_id, @peer_type)
      assert peer == build_peer()
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: #{@error_message}"} =
               Peer.add_peer(client, @room_id, @invalid_peer_type)
    end
  end

  describe "Peer.delete_peer/3" do
    setup do
      mock(fn
        %{
          method: :delete,
          url: @url <> "/room/" <> @room_id <> "/peer/" <> @peer_id
        } ->
          text("", status: 204)

        %{
          method: :delete,
          url: @url <> "/room/" <> @room_id <> "/peer/" <> @invalid_peer_id
        } ->
          json(%{"errors" => @error_message}, status: 404)
      end)
    end

    test "when request is valid", %{client: client} do
      assert :ok = Peer.delete_peer(client, @room_id, @peer_id)
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: #{@error_message}"} =
               Peer.delete_peer(client, @room_id, @invalid_peer_id)
    end
  end

  describe "Peer.peer_from_json/1" do
    test "when input is valid" do
      assert build_peer() == Peer.peer_from_json(build_peer_json())
    end

    test "when input is invalid" do
      catch_error(Peer.peer_from_json(%{"invalid_key" => 4}))
    end
  end

  defp build_peer() do
    %Peer{id: @peer_id, type: @peer_type}
  end

  defp build_peer_json() do
    %{"id" => @peer_id, "type" => @peer_type}
  end
end

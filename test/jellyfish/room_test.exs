defmodule Jellyfish.RoomTest do
  use ExUnit.Case

  import Tesla.Mock

  alias Jellyfish.{Client, Component, Peer, Room}

  @url "http://mockurl.com"

  @component_id "mock_component_id"
  @component_type "hls"
  @peer_id "mock_peer_id"
  @peer_type "webrtc"

  @room_id "mock_room_id"

  @invalid_peer_id "invalid_peer_id"
  @invalid_peer_type "abc"

  @invalid_component_id "invalid_component_id"
  @invalid_component_type "abc"

  @error_message "Mock error message"

  setup do
    middleware = [
      {Tesla.Middleware.BaseUrl, @url},
      Tesla.Middleware.JSON
    ]

    adapter = Tesla.Mock
    http_client = Tesla.client(middleware, adapter)

    %{client: %Client{http_client: http_client}}
  end

  describe "Room.add_component/4" do
    setup do
      valid_body = Jason.encode!(%{"options" => %{}, "type" => @component_type})
      invalid_body = Jason.encode!(%{"options" => %{}, "type" => @invalid_component_type})

      mock(fn
        %{
          method: :post,
          url: "#{@url}/room/#{@room_id}/component",
          body: ^valid_body
        } ->
          json(%{"data" => build_component_json()}, status: 201)

        %{
          method: :post,
          url: "#{@url}/room/#{@room_id}/component",
          body: ^invalid_body
        } ->
          json(%{"errors" => @error_message}, status: 400)
      end)
    end

    test "when request is valid", %{client: client} do
      assert {:ok, component} = Room.add_component(client, @room_id, @component_type)
      assert component == build_component()
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: #{@error_message}"} =
               Room.add_component(client, @room_id, @invalid_component_type)
    end
  end

  describe "Room.delete_component/3" do
    setup do
      mock(fn
        %{
          method: :delete,
          url: "#{@url}/room/#{@room_id}/component/#{@component_id}"
        } ->
          text("", status: 204)

        %{
          method: :delete,
          url: "#{@url}/room/#{@room_id}/component/#{@invalid_component_id}"
        } ->
          json(%{"errors" => @error_message}, status: 404)
      end)
    end

    test "when request is valid", %{client: client} do
      assert :ok = Room.delete_component(client, @room_id, @component_id)
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: #{@error_message}"} =
               Room.delete_component(client, @room_id, @invalid_component_id)
    end
  end

  describe "Room.add_peer/3" do
    setup do
      valid_body = Jason.encode!(%{"type" => @peer_type})
      invalid_body = Jason.encode!(%{"type" => @invalid_peer_type})

      mock(fn
        %{
          method: :post,
          url: "#{@url}/room/#{@room_id}/peer",
          body: ^valid_body
        } ->
          json(%{"data" => build_peer_json()}, status: 201)

        %{
          method: :post,
          url: "#{@url}/room/#{@room_id}/peer",
          body: ^invalid_body
        } ->
          json(%{"errors" => @error_message}, status: 400)
      end)
    end

    test "when request is valid", %{client: client} do
      assert {:ok, peer} = Room.add_peer(client, @room_id, @peer_type)
      assert peer == build_peer()
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: #{@error_message}"} =
               Room.add_peer(client, @room_id, @invalid_peer_type)
    end
  end

  describe "Room.delete_peer/3" do
    setup do
      mock(fn
        %{
          method: :delete,
          url: "#{@url}/room/#{@room_id}/peer/#{@peer_id}"
        } ->
          text("", status: 204)

        %{
          method: :delete,
          url: "#{@url}/room/#{@room_id}/peer/#{@invalid_peer_id}"
        } ->
          json(%{"errors" => @error_message}, status: 404)
      end)
    end

    test "when request is valid", %{client: client} do
      assert :ok = Room.delete_peer(client, @room_id, @peer_id)
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: #{@error_message}"} =
               Room.delete_peer(client, @room_id, @invalid_peer_id)
    end
  end

  defp build_component() do
    %Component{id: @component_id, type: @component_type}
  end

  defp build_component_json() do
    %{"id" => @component_id, "type" => @component_type}
  end

  defp build_peer() do
    %Peer{id: @peer_id, type: @peer_type}
  end

  defp build_peer_json() do
    %{"id" => @peer_id, "type" => @peer_type}
  end
end

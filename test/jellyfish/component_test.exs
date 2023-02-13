defmodule Jellyfish.SDK.ComponentTest do
  use ExUnit.Case

  import Tesla.Mock

  alias Jellyfish.SDK.{Client, Component}

  @url "http://mockurl.com"

  @component_id "mock_component_id"
  @component_type "hls"

  @room_id "mock_room_id"

  @invalid_component_id "invalid_component_id"
  @invalid_peer_component "abc"

  @error_message "Error message"

  setup do
    middleware = [
      {Tesla.Middleware.BaseUrl, @url},
      Tesla.Middleware.JSON
    ]

    adapter = Tesla.Mock
    http_request = Tesla.client(middleware, adapter)

    %{client: %Client{http_request: http_request}}
  end

  describe "Component.create_component/4" do
    setup do
      mock(fn
        %{
          method: :post,
          url: "#{@url}/room/#{@room_id}/component",
          body: "{\"options\":{},\"type\":\"#{@component_type}\"}"
        } ->
          json(%{"data" => build_component_json()}, status: 201)

        %{
          method: :post,
          url: "#{@url}/room/#{@room_id}/component",
          body: "{\"options\":{},\"type\":\"#{@invalid_peer_component}\"}"
        } ->
          json(%{"errors" => @error_message}, status: 400)
      end)
    end

    test "when request is valid", %{client: client} do
      assert {:ok, component} = Component.create_component(client, @room_id, @component_type, %{})
      assert component == build_component()
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: #{@error_message}"} =
               Component.create_component(client, @room_id, @invalid_peer_component, %{})
    end
  end

  describe "Component.delete_component/3" do
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
      assert :ok = Component.delete_component(client, @room_id, @component_id)
    end

    test "when request is invalid", %{client: client} do
      assert {:error, "Request failed: #{@error_message}"} =
               Component.delete_component(client, @room_id, @invalid_component_id)
    end
  end

  describe "Component.component_from_json/1" do
    test "when input is valid" do
      assert build_component() == Component.component_from_json(build_component_json())
    end

    test "when input is invalid" do
      catch_error(Component.component_from_json(%{"invalid_key" => 3}))
    end
  end

  defp build_component() do
    %Component{id: @component_id, type: @component_type}
  end

  defp build_component_json() do
    %{"id" => @component_id, "type" => @component_type}
  end
end

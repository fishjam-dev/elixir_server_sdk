defmodule Jellyfish.ClientTest do
  use ExUnit.Case

  alias Jellyfish.Client

  @server_address "localhost:5002"
  @server_api_token "valid-token"

  describe "creates client struct" do
    test "with connection options passed explictly" do
      address_with_prefix = "http://#{@server_address}"

      client =
        Client.new(
          server_address: @server_address,
          server_api_token: @server_api_token,
          secure?: false
        )

      assert %Client{
               http_client: %Tesla.Client{
                 adapter: {Tesla.Adapter.Mint, :call, [[]]},
                 pre: [
                   {Tesla.Middleware.BaseUrl, :call, [^address_with_prefix]},
                   {Tesla.Middleware.BearerAuth, :call, [[token: @server_api_token]]},
                   {Tesla.Middleware.JSON, :call, [[]]}
                 ]
               }
             } = client
    end

    test "with connection options from config" do
      :ok =
        Application.put_all_env([
          {
            :jellyfish_server_sdk,
            [
              {:server_address, @server_address},
              {:server_api_token, @server_api_token},
              {:secure?, true}
            ]
          }
        ])

      addres_with_prefix = "https://#{@server_address}"
      client = Client.new()

      assert %Client{
               http_client: %Tesla.Client{
                 adapter: {Tesla.Adapter.Mint, :call, [[]]},
                 pre: [
                   {Tesla.Middleware.BaseUrl, :call, [^addres_with_prefix]},
                   {Tesla.Middleware.BearerAuth, :call, [[token: @server_api_token]]},
                   {Tesla.Middleware.JSON, :call, [[]]}
                 ]
               }
             } = client

      Application.delete_env(:jellyfish_server_sdk, :server_address)
      Application.delete_env(:jellyfish_server_sdk, :server_api_token)
      Application.delete_env(:jellyfish_server_sdk, :secure?)
    end

    test "when address contains protocol prefix" do
      address_with_prefix = "http://#{@server_address}"

      assert_raise(
        Jellyfish.Exception.ProtocolPrefixError,
        fn ->
          Client.new(server_address: address_with_prefix, server_api_token: @server_api_token)
        end
      )
    end

    test "when options are not passed and config is not set" do
      :ok = Application.delete_env(:jellyfish_server_sdk, :server_address, [])
      :ok = Application.delete_env(:jellyfish_server_sdk, :server_api_token, [])

      assert_raise(
        ArgumentError,
        fn -> Client.new() end
      )
    end
  end

  test "update client address" do
    client =
      Client.new(
        server_address: @server_address,
        server_api_token: @server_api_token,
        secure?: true
      )

    addres_with_prefix = "https://#{@server_address}"

    assert %Client{
             http_client: %Tesla.Client{
               adapter: {Tesla.Adapter.Mint, :call, [[]]},
               pre: [
                 {Tesla.Middleware.BaseUrl, :call, [^addres_with_prefix]},
                 {Tesla.Middleware.BearerAuth, :call, [[token: @server_api_token]]},
                 {Tesla.Middleware.JSON, :call, [[]]}
               ]
             }
           } = client

    new_address = "jellyfish2:5005"
    addres_with_prefix = "https://#{new_address}"

    client = Client.update_address(client, new_address)

    assert %Client{
             http_client: %Tesla.Client{
               adapter: {Tesla.Adapter.Mint, :call, [[]]},
               pre: [
                 {Tesla.Middleware.BaseUrl, :call, [^addres_with_prefix]},
                 {Tesla.Middleware.BearerAuth, :call, [[token: @server_api_token]]},
                 {Tesla.Middleware.JSON, :call, [[]]}
               ]
             }
           } = client
  end
end

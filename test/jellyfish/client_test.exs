defmodule Jellyfish.ClientTest do
  use ExUnit.Case

  alias Jellyfish.Client

  @url "https://somemockurl.com"

  describe "sdk" do
    test "creates client struct" do
      server_api_token = "mock_token"
      client = Client.new(@url, server_api_token)

      assert %Client{
               http_client: %Tesla.Client{
                 adapter: {Tesla.Adapter.Mint, :call, [[]]},
                 pre: [
                   {Tesla.Middleware.BaseUrl, :call, [@url]},
                   {Tesla.Middleware.BearerAuth, :call, [[token: ^server_api_token]]},
                   {Tesla.Middleware.JSON, :call, [[]]}
                 ]
               }
             } = client
    end
  end
end

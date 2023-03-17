defmodule Jellyfish.ClientTest do
  use ExUnit.Case

  alias Jellyfish.Client

  @url "https://somemockurl.com"

  describe "sdk" do
    test "creates client struct" do
      client = Client.new(@url)

      assert %Client{
               http_client: %Tesla.Client{
                 adapter: {Tesla.Adapter.Mint, :call, [[]]},
                 pre: [
                   {Tesla.Middleware.BaseUrl, :call, [@url]},
                   {Tesla.Middleware.JSON, :call, [[]]}
                 ]
               }
             } = client
    end
  end
end

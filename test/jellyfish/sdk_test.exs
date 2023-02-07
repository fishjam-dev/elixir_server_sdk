defmodule Jellyfish.SDKTest do
  use ExUnit.Case

  alias Jellyfish.SDK

  @url "https://somemockurl.com"

  describe "sdk" do
    test "creates client struct" do
      client = SDK.new(@url)

      assert %Tesla.Client{
               adapter: {Tesla.Adapter.Hackney, :call, [[]]},
               pre: [
                 {Tesla.Middleware.BaseUrl, :call, [@url]},
                 {Tesla.Middleware.JSON, :call, [[]]}
               ]
             } = client
    end
  end
end

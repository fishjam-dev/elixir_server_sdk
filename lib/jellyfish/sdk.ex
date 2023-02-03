defmodule Jellyfish.SDK do
  @moduledoc """
  Elixir server SDK for Jellyfish
  """

  alias Tesla.Client

  @spec client(String.t()) :: Client.t()
  def client(url) do
    middleware = [
      {Tesla.Middleware.BaseUrl, url},
      {Tesla.Middleware.Headers, [{"content-type", "application/json"}]},
      Tesla.Middleware.JSON
    ]

    adapter = Tesla.Adapter.Hackney

    Tesla.client(middleware, adapter)
  end
end

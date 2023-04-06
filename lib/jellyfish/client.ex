defmodule Jellyfish.Client do
  @moduledoc """
  Defines a `t:Jellyfish.Client.t/0`.

  By default, Mint adapter for [Tesla](https://github.com/elixir-tesla/tesla) is used to make HTTP requests, but it can be changed:
  ```
  # config.exs
  config :jellyfish_server_sdk, tesla_adapter: Tesla.Adapter.Hackney

  # mix.exs
  defp deps do
    [
      {:hackney, "~> 1.10"}
    ]
  end
  ```
  For the list of supported Tesla adapters refer to [Tesla docs](https://hexdocs.pm/tesla/readme.html#adapters).
  """

  @enforce_keys [
    :http_client
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          http_client: Tesla.Client.t()
        }

  @doc """
  Creates new instance of `t:Jellyfish.SDK.Client.t/0`.

  ## Parameters

    * `address` - url or IP address of the Jellyfish server instance
    * `token` - token used for authorizing HTTP requests. It's the same
    token as the one configured in Jellyfish.
  """
  @spec new(String.t(), String.t()) :: t()
  def new(address, token) do
    middleware = [
      {Tesla.Middleware.BaseUrl, address},
      {Tesla.Middleware.BearerAuth, token: token},
      Tesla.Middleware.JSON
    ]

    adapter = Application.get_env(:jellyfish_server_sdk, :tesla_adapter, Tesla.Adapter.Mint)
    http_client = Tesla.client(middleware, adapter)

    %__MODULE__{http_client: http_client}
  end
end

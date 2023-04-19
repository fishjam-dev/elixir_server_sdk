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

  alias Jellyfish.Utils

  @enforce_keys [
    :http_client
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          http_client: Tesla.Client.t()
        }

  @doc """
  Creates a new instance of `t:Jellyfish.Client.t/0`.

  ## Options

    * `:server_address` - url or IP address of the Jellyfish server instance.
    * `:server_api_token` - token used for authorizing HTTP requests. It's the same
    token as the one configured in Jellyfish.

  When an option is not explicily passed, value set in `config.exs` is used:
  ```
  # in config.exs
  config :jellyfish_server_sdk, 
    server_address: "http://you-jellyfish-server-address.com",
    server_api_token: "your-jellyfish-token",
  ```
  """
  @spec new(server_address: String.t(), server_api_token: String.t()) ::
          {:ok, t()} | {:error, term()}
  def new(opts) do
    with {:ok, {address, api_token}} <- Utils.get_options_or_defaults(opts) do
      adapter = Application.get_env(:jellyfish_server_sdk, :tesla_adapter, Tesla.Adapter.Mint)

      middleware = [
        {Tesla.Middleware.BaseUrl, address},
        {Tesla.Middleware.BearerAuth, token: api_token},
        Tesla.Middleware.JSON
      ]

      http_client = Tesla.client(middleware, adapter)

      {:ok, %__MODULE__{http_client: http_client}}
    else
      {:error, :missing_url_protocol_prefix} = error -> error
    end
  end
end

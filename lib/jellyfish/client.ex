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

  @typedoc """
  Options needed to open connection to Jellyfish server.

  * `:server_address` - address of the Jellyfish server instance.
  * `:server_api_token` - token used for authorizing HTTP requests and WebSocket connection.
  It's the same token as the one configured in Jellyfish.
  * `:secure?` - if `true`, use HTTPS and WSS instead of HTTP and WS, `false` by default.

  When an option is not explicily passed, value set in `config.exs` is used:
  ```
  # in config.exs
  config :jellyfish_server_sdk,
    server_address: "localhost:5002",
    server_api_token: "your-jellyfish-token",
    secure?: true
  ```
  """
  @type connection_options :: [
          server_address: String.t(),
          server_api_token: String.t(),
          secure?: boolean()
        ]

  @doc """
  Creates a new instance of `t:Jellyfish.Client.t/0`.

  For information about options, see `t:connection_options/0`.
  """
  @spec new(connection_options()) :: t()
  def new(opts \\ []) do
    {address, api_token, secure?} = Utils.get_options_or_defaults(opts)
    address = if secure?, do: "https://#{address}", else: "http://#{address}"
    adapter = Application.get_env(:jellyfish_server_sdk, :tesla_adapter, Tesla.Adapter.Mint)

    middleware = [
      {Tesla.Middleware.BaseUrl, address},
      {Tesla.Middleware.BearerAuth, token: api_token},
      Tesla.Middleware.JSON
    ]

    http_client = Tesla.client(middleware, adapter)

    %__MODULE__{http_client: http_client}
  end
end

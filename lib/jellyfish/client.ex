defmodule Jellyfish.Client do
  @moduledoc """
  Defines a `t:Jellyfish.SDK.Client.t/0`.

  By default, Mint adapter for Tesla is used to make HTTP request, but it can be changed:
  ```
  # config.exs
  config :jellyfish, tesla_adapter: Tesla.Adapter.Hackney

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
  """
  @spec new(String.t()) :: t()
  def new(address) do
    middleware = [
      {Tesla.Middleware.BaseUrl, address},
      Tesla.Middleware.JSON
    ]

    adapter = Application.get_env(:jellyfish, :tesla_adapter, Tesla.Adapter.Mint)
    http_client = Tesla.client(middleware, adapter)

    %__MODULE__{http_client: http_client}
  end
end

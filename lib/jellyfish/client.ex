defmodule Jellyfish.Client do
  @moduledoc """
  Defines a `t:Jellyfish.SDK.Client.t/0`.
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

    adapter = Tesla.Adapter.Hackney
    http_client = Tesla.client(middleware, adapter)

    %__MODULE__{http_client: http_client}
  end
end

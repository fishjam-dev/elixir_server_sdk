defmodule Jellyfish.SDK.Client do
  @moduledoc """
  This module defines a `t:Jellyfish.SDK.Client.t/0` that stores all of the data related to SDK state.
  """
  @typedoc """
  * `http_request` - stores information used to make HTTP requests
  """
  @type t :: %__MODULE__{
          http_client: Tesla.Client.t()
        }

  defstruct [:http_client]

  @doc ~S"""
  Creates new instance of `t:Jellyfish.SDK.Client.t/0` struct

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

defmodule Jellyfish.Utils do
  @moduledoc false

  @valid_prefixes ["http://", "https://"]

  @spec get_options_or_defaults(server_address: String.t(), server_api_token: String.t()) ::
          {:ok, {String.t(), String.t()}} | {:error, term()}
  def get_options_or_defaults(opts) do
    server_address =
      opts[:server_address] || Application.fetch_env!(:jellyfish_server_sdk, :server_address)

    server_api_token =
      opts[:server_api_token] || Application.fetch_env!(:jellyfish_server_sdk, :server_api_token)

    if String.starts_with?(server_address, @valid_prefixes) do
      {:ok, {server_address, server_api_token}}
    else
      {:error, :invalid_url_protocol_prefix}
    end
  end
end

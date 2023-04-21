defmodule Jellyfish.Utils do
  @moduledoc false

  alias Jellyfish.Client
  alias Jellyfish.Exception.ProtocolPrefixError

  @protocol_prefixes ["http://", "https://", "ws://", "wss://"]

  @spec get_options_or_defaults(Client.connection_options()) ::
          {String.t(), String.t(), boolean()}
  def get_options_or_defaults(opts) do
    server_address =
      opts[:server_address] || Application.fetch_env!(:jellyfish_server_sdk, :server_address)

    server_api_token =
      opts[:server_api_token] || Application.fetch_env!(:jellyfish_server_sdk, :server_api_token)

    secure? =
      Keyword.get(opts, :secure?, Application.get_env(:jellyfish_server_sdk, :secure?, false))

    if String.starts_with?(server_address, @protocol_prefixes), do: raise(ProtocolPrefixError)

    {server_address, server_api_token, secure?}
  end
end

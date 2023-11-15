defmodule Jellyfish.Utils do
  @moduledoc false

  alias Jellyfish.Client
  alias Jellyfish.Exception.{OptionsError, ProtocolPrefixError, StructureError}
  alias Tesla.Env

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

    check_prefixes(server_address)

    {server_address, server_api_token, secure?}
  end

  @spec check_prefixes(String.t()) :: nil
  def check_prefixes(server_address) do
    if String.starts_with?(server_address, @protocol_prefixes), do: raise(ProtocolPrefixError)
  end

  @type error :: {:ok, %Env{}} | {:error, term()}

  @spec handle_response_error(error()) :: {:error, term()}
  def handle_response_error({:ok, %Env{body: %{"errors" => error}}}),
    do: {:error, "Request failed: #{error}"}

  def handle_response_error({:ok, %Env{body: _body}}), do: raise(StructureError)
  def handle_response_error({:error, :component_validation}), do: raise(OptionsError)
  def handle_response_error({:error, reason}), do: {:error, reason}
end

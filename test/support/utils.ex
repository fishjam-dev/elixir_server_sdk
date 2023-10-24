defmodule Jellyfish.Test.Utils do
  @moduledoc false

  def read_server_address() do
    Application.fetch_env(:jellyfish_server_sdk, :local_server_address)
    |> case do
      {:ok, value} -> value
      :error -> Application.fetch_env!(:jellyfish_server_sdk, :server_address)
    end
  end

  def read_webhook_address(webhook_port) do
    webhook_address =
      Application.fetch_env(:jellyfish_server_sdk, :local_webhook_address)
      |> case do
        {:ok, value} -> value
        :error -> Application.fetch_env!(:jellyfish_server_sdk, :webhook_address)
      end

    "http://#{webhook_address}:#{webhook_port}/"
  end
end

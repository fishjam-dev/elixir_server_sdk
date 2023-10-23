defmodule Jellyfish.Test.Utils do
  @moduledoc false

  def read_server_address() do
    System.get_env(
      "SERVER_ADDRESS",
      Application.fetch_env!(:jellyfish_server_sdk, :server_address)
    )
  end

  def read_webhook_address(webhook_port) do
    webhook_address =
      System.get_env(
        "WEBHOOK_ADDRESS",
        Application.fetch_env!(:jellyfish_server_sdk, :webhook_address)
      )

    "http://#{webhook_address}:#{webhook_port}/"
  end
end

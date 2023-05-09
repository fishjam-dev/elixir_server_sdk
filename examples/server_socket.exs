Mix.install([
  {:jellyfish_server_sdk, path: __DIR__ |> Path.join("..") |> Path.expand()}
])

server_api_token = "development"

{:ok, pid} =
  Jellyfish.Notifier.start(server_address: "localhost:4000", server_api_token: server_api_token)

defmodule Receiver do
  def receive_notification() do
    receive do
      {:jellyfish, server_notification} ->
        IO.inspect(server_notification, label: :server_notification)
    after
      150_000 ->
        IO.inspect(:timeout)
    end

    receive_notification()
  end
end

Receiver.receive_notification()

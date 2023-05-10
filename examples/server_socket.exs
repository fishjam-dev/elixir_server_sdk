Mix.install([
  {:jellyfish_server_sdk, path: __DIR__ |> Path.join("..") |> Path.expand()},
  {:protobuf, "~> 0.12.0"},
])

server_api_token = "development"

{:ok, _pid} =
  Jellyfish.Notifier.start(server_address: "localhost:4000", server_api_token: server_api_token)

receive_notification = fn receive_notification ->
  receive do
    {:jellyfish, server_notification} ->
      IO.inspect(server_notification, label: :server_notification)
  after
    150_000 ->
      IO.inspect(:timeout)
  end

  receive_notification.(receive_notification)
end

receive_notification.(receive_notification)

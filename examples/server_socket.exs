Mix.install(
  [
    {:jellyfish_server_sdk, path: __DIR__ |> Path.join("..") |> Path.expand()}
  ],
  force: true
)

server_address = "localhost:5002"
server_api_token = "development"

{:ok, notifier} =
  Jellyfish.Notifier.start(server_address: server_address, server_api_token: server_api_token)

{:ok, _rooms} = Jellyfish.Notifier.subscribe_server_notifications(notifier, :all)
{:ok, :all} = Jellyfish.Notifier.subscribe_metrics(notifier)

receive_notification = fn receive_notification ->
  receive do
    {:jellyfish, event} ->
      IO.inspect(event, label: :event)
  after
    150_000 ->
      IO.inspect(:timeout)
  end

  receive_notification.(receive_notification)
end

receive_notification.(receive_notification)

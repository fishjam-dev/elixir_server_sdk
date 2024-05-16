Mix.install(
  [
    {:fishjam_server_sdk, path: __DIR__ |> Path.join("..") |> Path.expand()}
  ],
  force: true
)

server_address = "localhost:5002"
server_api_token = "development"

{:ok, notifier} =
  Fishjam.WSNotifier.start(server_address: server_address, server_api_token: server_api_token)

{:ok, _rooms} = Fishjam.WSNotifier.subscribe_server_notifications(notifier, :all)
:ok = Fishjam.WSNotifier.subscribe_metrics(notifier)

receive_notification = fn receive_notification ->
  receive do
    {:fishjam, event} ->
      IO.inspect(event, label: :event)
  after
    150_000 ->
      IO.inspect(:timeout)
  end

  receive_notification.(receive_notification)
end

receive_notification.(receive_notification)

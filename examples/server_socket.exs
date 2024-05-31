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

:ok = Fishjam.WSNotifier.subscribe_server_notifications(notifier)
:ok = Fishjam.WSNotifier.subscribe_metrics(notifier)

defmodule Notification do
  def receive() do
    receive do
      {:fishjam, event} ->
        IO.inspect(event, label: :event)
    after
      15_000 ->
        IO.inspect(:timeout)
    end

    receive()
  end
end

Notification.receive()

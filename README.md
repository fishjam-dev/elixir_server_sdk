# Fishjam Elixir Server SDK

[![Hex.pm](https://img.shields.io/hexpm/v/fishjam_server_sdk.svg)](https://hex.pm/packages/fishjam_server_sdk)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/fishjam_server_sdk/)
[![codecov](https://codecov.io/gh/fishjam-dev/elixir_server_sdk/branch/master/graph/badge.svg?token=ByIko4o5U8)](https://codecov.io/gh/fishjam-dev/elixir_server_sdk)
[![CircleCI](https://circleci.com/gh/fishjam-dev/elixir_server_sdk.svg?style=svg)](https://circleci.com/gh/fishjam-dev/elixir_server_sdk)

Elixir server SDK for [Fishjam](https://github.com/fishjam-dev/fishjam).
Currently it allows for:

- making API calls to Fishjam server (QoL wrapper for HTTP requests)
- listening to Fishjam server events via WebSocket

## Installation

The package can be installed by adding `fishjam_server_sdk` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:fishjam_server_sdk, "~> 0.5.0"}
  ]
end
```

## Fishjam connection configuration

Define the connection configuration in the mix config,
specifying server address and authentication token
(for more information see [Fishjam docs](https://fishjam-dev.github.io/fishjam-docs/getting_started/authentication))
``` config.exs
config :fishjam_server_sdk,
  server_address: "localhost:5002",
  server_api_token: "your-fishjam-token",
  secure?: true
```

Alternatively, the connection options can be provided when creating a `Fishjam.Client` or starting `Fishjam.WSNotifier`:

```elixir
client =
    Fishjam.Client.new(server_address: "localhost:5002", server_api_token: "your-fishjam-token")

{:ok, notifier} =
    Fishjam.WSNotifier.start(
      server_address: "localhost:5002",
      server_api_token: "your-fishjam-token"
    )
```

## Usage

Make API calls to Fishjam and receive server events:

```elixir
# start process responsible for receiving events
{:ok, notifier} = Fishjam.WSNotifier.start()
:ok = Fishjam.WSNotifier.subscribe_server_notifications(notifier)

# create HTTP client instance
client = Fishjam.Client.new()

# Create room
{:ok, %Fishjam.Room{id: room_id}, fishjam_address} = Fishjam.Room.create(client, max_peers: 10)

room_id
# => "8878cd13-99a6-40d6-8d7e-8da23d803dab"

# Add peer
{:ok, %Fishjam.Peer{id: peer_id}, peer_token} =
    Fishjam.Room.add_peer(client, room_id, Fishjam.Peer.WebRTC)

receive do
  {:fishjam, %Fishjam.Notification.PeerConnected{room_id: ^room_id, peer_id: ^peer_id}} ->
    # handle the notification
end

# Delete peer
:ok = Fishjam.Room.delete_peer(client, room_id, peer_id)
```

List of structs representing events can be found in the [docs](https://hexdocs.pm/fishjam_server_sdk).

## Testing

When calling `mix test` it will automatically start the Fishjam container under the hood.
Tests on CI are run with the use of docker-compose, to run it locally in the same way as on CI run `mix integration_test`.

## Copyright and License

Copyright 2023, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=fishjam)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=fishjam)

Licensed under the [Apache License, Version 2.0](LICENSE)

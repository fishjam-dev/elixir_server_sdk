# Jellyfish Elixir Server SDK

[![Hex.pm](https://img.shields.io/hexpm/v/jellyfish_server_sdk.svg)](https://hex.pm/packages/jellyfish_server_sdk)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/jellyfish_server_sdk/)
[![codecov](https://codecov.io/gh/jellyfish-dev/elixir_server_sdk/branch/master/graph/badge.svg?token=ByIko4o5U8)](https://codecov.io/gh/jellyfish-dev/elixir_server_sdk)
[![CircleCI](https://circleci.com/gh/jellyfish-dev/elixir_server_sdk.svg?style=svg)](https://circleci.com/gh/jellyfish-dev/elixir_server_sdk)

Elixir server SDK for [Jellyfish](https://github.com/jellyfish-dev/jellyfish).
Currently it allows for:

- making API calls to Jellyfish server (QoL wrapper for HTTP requests)
- listening to Jellyfish server events via WebSocket

## Installation

The package can be installed by adding `jellyfish_server_sdk` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:jellyfish_server_sdk, "~> 0.1.1"}
  ]
end
```

## Jellyfish connection configuration

Define the connection configuration in the mix config,
specifying server address and authentication token
(for more information see [Jellyfish docs](https://jellyfish-dev.github.io/jellyfish-docs/getting_started/authentication))
``` config.exs
config :jellyfish_server_sdk,
  server_address: "localhost:5002",
  server_api_token: "your-jellyfish-token",
  secure?: true
```

Alternatively, the connection options can be provided when creating a `Jellyfish.Client` or starting `Jellyfish.Notifier`:

```
client =
    Jellyfish.Client.new(server_address: "localhost:5002", server_api_token: "your-jellyfish-token")

{:ok, notifier} =
    Jellyfish.Notifier.start(
      server_address: "localhost:5002",
      server_api_token: "your-jellyfish-token"
    )
```

## Usage

Make API calls to Jellyfish and receive server events:

```elixir
# start process responsible for receiving events
{:ok, notifier} = Jellyfish.Notifier.start()
{:ok, _rooms} = Jellyfish.Notifier.subscribe_server_notifications(notifier, :all)

# create HTTP client instance
client = Jellyfish.Client.new()

# Create room
{:ok, %Jellyfish.Room{id: room_id}, jellyfish_address} = Jellyfish.Room.create(client, max_peers: 10)

room_id
# => "8878cd13-99a6-40d6-8d7e-8da23d803dab"

# Add peer
{:ok, %Jellyfish.Peer{id: peer_id}, peer_token} =
    Jellyfish.Room.add_peer(client, room_id, Jellyfish.Peer.WebRTC)

receive do
  {:jellyfish, %Jellyfish.Notification.PeerConnected{room_id: ^room_id, peer_id: ^peer_id}} ->
    # handle the notification
end

# Delete peer
:ok = Jellyfish.Room.delete_peer(client, room_id, peer_id)
```

List of structs representing events can be found in the [docs](https://hexdocs.pm/jellyfish_server_sdk).

## Testing

When calling `mix test` it will automatically start the Jellyfish container under the hood.
Tests on CI are run with the use of docker-compose, to run it locally in the same way as on CI run `mix integration_test`.

## Copyright and License

Copyright 2023, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=jellyfish)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=jellyfish)

Licensed under the [Apache License, Version 2.0](LICENSE)

# Jellyfish Elixir Server SDK

[![Hex.pm](https://img.shields.io/hexpm/v/jellyfish_server_sdk.svg)](https://hex.pm/packages/jellyfish_server_sdk)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/jellyfish_server_sdk/)
[![codecov](https://codecov.io/gh/jellyfish-dev/server_sdk_elixir/branch/master/graph/badge.svg?token=ByIko4o5U8)](https://codecov.io/gh/jellyfish-dev/server_sdk_elixir)
[![CircleCI](https://circleci.com/gh/jellyfish-dev/server_sdk_elixir.svg?style=svg)](https://circleci.com/gh/jellyfish-dev/server_sdk_elixir)

Elixir server SDK for [Jellyfish](https://github.com/jellyfish-dev/jellyfish).
Currently it allows for:

- making API calls to Jellyfish server (QoL wrapper for HTTP requests)

## Installation

The package can be installed by adding `jellyfish_server_sdk` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:jellyfish_server_sdk, "~> 0.1.0"}
  ]
end
```

## Usage

Make API calls to Jellyfish (authentication required, for more information see [Jellyfish docs](https://jellyfish-dev.github.io/jellyfish-docs/getting_started/authentication)):

```elixir
client = Jellyfish.Client.new("http://address-of-your-server.com", "your-jellyfish-token")

# Create room
{:ok, %Jellyfish.Room{id: room_id}} = Jellyfish.Room.create(client, max_peers: 10)

room_id
# => "8878cd13-99a6-40d6-8d7e-8da23d803dab"

# Add peer
{:ok, %Jellyfish.Peer{id: peer_id}, peer_token} = Jellyfish.Room.add_peer(client, room_id, "webrtc")

# Delete peer
:ok = Jellyfish.Room.delete_peer(client, room_id, peer_id)
```

## Copyright and License

Copyright 2023, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=jellyfish)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=jellyfish)

Licensed under the [Apache License, Version 2.0](LICENSE)

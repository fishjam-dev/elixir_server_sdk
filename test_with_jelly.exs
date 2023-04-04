alias Jellyfish.{Client, Peer, Room}

client = Client.new("http://localhost:4000")

{:ok, %Room{id: room_id}} = Room.create(client, max_peers: 10)

{:ok, %Peer{id: peer_id}, auth_token} = Room.add_peer(client, room_id, "webrtc") |> IO.inspect()

IO.inspect(auth_token, label: :token)

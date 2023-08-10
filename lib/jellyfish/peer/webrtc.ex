defmodule Jellyfish.Peer.WebRTC do
  @moduledoc """
  Options for the WebRTC peer.

  For the description of these options refer to [Jellyfish
  documentation](https://jellyfish-dev.github.io/jellyfish-docs/getting_started/peers/webrtc).
  """

  @enforce_keys []
  defstruct @enforce_keys ++
              [
                enable_simulcast: true
              ]

  @type t :: %__MODULE__{
          enable_simulcast: boolean()
        }
end

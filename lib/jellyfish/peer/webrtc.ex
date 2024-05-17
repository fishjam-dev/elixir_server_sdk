defmodule Fishjam.Peer.WebRTC do
  @moduledoc """
  Options for the WebRTC peer.

  For the description of these options refer to [Fishjam
  documentation](https://fishjam-dev.github.io/fishjam-docs/getting_started/peers/webrtc).
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

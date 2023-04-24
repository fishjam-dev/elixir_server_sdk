defmodule Jellyfish.Component.RTSP do
  @moduledoc """
  Options for the RTSP component.

  For the description of these options refer to [Jellyfish documentation](https://jellyfish-dev.github.io/jellyfish-docs/getting_started/components/rtsp)
  """

  @enforce_keys [:sourceUri]
  defstruct @enforce_keys ++
              [
                rtpPort: 20_000,
                reconnectDelay: 15_000,
                keepAliveInterval: 15_000,
                pierceNat: true
              ]

  @type t :: %__MODULE__{
          sourceUri: URI.t(),
          rtpPort: 1..65_535,
          reconnectDelay: non_neg_integer(),
          keepAliveInterval: non_neg_integer(),
          pierceNat: boolean()
        }
end

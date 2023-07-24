defmodule Jellyfish.Component.RTSP do
  @moduledoc """
  Options for the RTSP component.

  For the description of these options refer to [Jellyfish
  documentation](https://jellyfish-dev.github.io/jellyfish-docs/getting_started/components/rtsp).
  """

  @behaviour Jellyfish.Component.Deserializer

  @enforce_keys [:source_uri]
  defstruct @enforce_keys ++
              [
                rtp_port: 20_000,
                reconnect_delay: 15_000,
                keep_alive_interval: 15_000,
                pierce_nat: true
              ]

  @type t :: %__MODULE__{
          source_uri: URI.t(),
          rtp_port: 1..65_535,
          reconnect_delay: non_neg_integer(),
          keep_alive_interval: non_neg_integer(),
          pierce_nat: boolean()
        }
  @impl true
  def from_json(_component), do: %{}
  @impl true
  def from_proto(_component), do: %{}
end

defmodule Jellyfish.Component.HLS do
  @moduledoc """
  Options for the HLS component.

  For the description of these options refer to [Jellyfish
  documentation](https://jellyfish-dev.github.io/jellyfish-docs/getting_started/components/hls).
  """

  @behaviour Jellyfish.Component.Deserializer

  @enforce_keys []
  defstruct @enforce_keys ++
              [
                low_latency: false
              ]

  @type t :: %__MODULE__{
          low_latency: boolean()
        }

  @impl true
  def metadata_from_json(%{"playable" => playable, "lowLatency" => low_latency}) do
    %{playable: playable, low_latency: low_latency}
  end
end

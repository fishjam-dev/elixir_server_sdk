defmodule Fishjam.Component.HLS do
  @moduledoc """
  Options for the HLS component.

  For the description of these options refer to [Fishjam
  documentation](https://fishjam-dev.github.io/fishjam-docs/getting_started/components/hls).
  """

  @behaviour Fishjam.Component.Deserializer

  @type credentials :: %{
          access_key_id: String.t(),
          secret_access_key: String.t(),
          region: String.t(),
          bucket: String.t()
        }

  @enforce_keys []
  defstruct @enforce_keys ++
              [
                low_latency: false,
                persistent: false,
                target_window_duration: nil,
                subscribe_mode: :auto,
                s3: nil
              ]

  @type t :: %__MODULE__{
          low_latency: boolean(),
          persistent: boolean(),
          target_window_duration: pos_integer() | nil,
          subscribe_mode: :auto | :manual,
          s3: credentials() | nil
        }

  @impl true
  def properties_from_json(%{
        "playable" => playable,
        "lowLatency" => low_latency,
        "persistent" => persistent,
        "targetWindowDuration" => target_window_duration,
        "subscribeMode" => subscribe_mode
      }) do
    %{
      playable: playable,
      low_latency: low_latency,
      persistent: persistent,
      target_window_duration: target_window_duration,
      subscribe_mode: subscribe_mode
    }
  end
end

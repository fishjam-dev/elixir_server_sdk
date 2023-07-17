defmodule Jellyfish.Metrics do
  @moduledoc false

  defmodule MetricsReport do
    @moduledoc nil

    @enforce_keys [:metrics]
    defstruct @enforce_keys

    @typedoc """
    Describes a WebRTC metrics report, which is periodically sent once the process subscribes for metrics events.

    The report is a map, with each entry being a `metric_name => value` pair, where value can be a boolean, number, string or a map with the same structure.

    Here is a sample report:
    ```
    %Jellyfish.Metrics.MetricsReport{
    metrics: %{
     "inbound-rtp.frames" => 406,
     "inbound-rtp.keyframes" => 9,
     "room_id=32b1e952-9efa-4c29-88bc-36d7a536f95a" => %{
       "endpoint_id=4354f193-e787-4f07-b445-7e246b702ba6" => %{
         "ice.protocol" => "udp",
         "track_id=4354f193-e787-4f07-b445-7e246b702ba6:cd2013a8-ea9f-4612-aa99-05149172e6a5:" => %{
           "inbound-rtp.bytes_received" => 379567,
           "inbound-rtp.bytes_received-per-second" => 68355.64435564436,
           "inbound-rtp.encoding" => "VP8",
           "rtx_stream" => %{
             "inbound-rtp.bytes_received" => 7680,
             "inbound-rtp.bytes_received-per-second" => 0.0
           },
           "track.metadata" => %{
             "active" => true,
             "type" => "camera"
           }
         },
         "track_id=5ead4135-6ab2-4872-8c04-daca02f5116d:63543a41-b3ff-4a80-91fd-91cfdea13cbe" => %{
           "outbound-rtp.bytes" => 354075,
           "outbound-rtp.bytes-per-second" => 63083.91608391608,
           "outbound-rtp.variant" => "high"
         }
       }
    }
    ```
    """

    @type t :: %__MODULE__{
            metrics: map()
          }
  end
end

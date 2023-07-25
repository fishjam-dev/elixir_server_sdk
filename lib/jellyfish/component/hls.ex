defmodule Jellyfish.Component.HLS do
  @moduledoc """
  Options for the HLS component.

  For the description of these options refer to [Jellyfish
  documentation](https://jellyfish-dev.github.io/jellyfish-docs/getting_started/components/hls).
  """

  @behaviour Jellyfish.Component.Deserializer
  @enforce_keys []
  defstruct @enforce_keys ++ []

  @type t :: %__MODULE__{}

  @impl true
  def metadata_from_json(%{"playable" => playable}) do
    %{playable: playable}
  end

  @impl true
  def metadata_from_proto(%{playable: playable}) do
    %{playable: playable}
  end
end

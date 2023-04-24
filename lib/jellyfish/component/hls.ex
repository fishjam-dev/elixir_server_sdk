defmodule Jellyfish.Component.HLS do
  @moduledoc """
  Options for the HLS component.

  For the description of these options refer to [Jellyfish documentation](https://jellyfish-dev.github.io/jellyfish-docs/getting_started/components/hls)
  """

  @enforce_keys []
  defstruct @enforce_keys ++ []

  @type t :: %__MODULE__{}
end

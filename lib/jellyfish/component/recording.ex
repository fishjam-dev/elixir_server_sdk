defmodule Fishjam.Component.Recording do
  @moduledoc """
  Options for the recording component.

  For the description of these options refer to [Fishjam
  documentation](https://fishjam-dev.github.io/fishjam-docs/getting_started/components/recording).
  """

  @behaviour Fishjam.Component.Deserializer

  alias Fishjam.Component.HLS

  @enforce_keys []
  defstruct @enforce_keys ++ [credentials: nil, path_prefix: nil, subscribe_mode: :auto]

  @type t :: %__MODULE__{
          credentials: HLS.credentials() | nil,
          path_prefix: Path.t() | nil,
          subscribe_mode: :manual | :auto
        }

  @impl true
  def properties_from_json(%{"subscribeMode" => subscribe_mode}) do
    %{subscribe_mode: subscribe_mode}
  end
end

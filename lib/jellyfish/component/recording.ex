defmodule Jellyfish.Component.Recording do
  @moduledoc """
  Options for the recording component.

  For the description of these options refer to [Jellyfish
  documentation](https://jellyfish-dev.github.io/jellyfish-docs/getting_started/components/recording).
  """

  @behaviour Jellyfish.Component.Deserializer

  alias Jellyfish.Component.HLS

  @enforce_keys []
  defstruct @enforce_keys ++ [credentials: nil, path_prefix: nil, subscribe_mode: :auto]

  @type t :: %__MODULE__{
          credentials: HLS.credentials() | nil,
          path_prefix: Path.t() | nil,
          subscribe_mode: :manual | :auto
        }

  @impl true
  def properties_from_json(%{"pathPrefix" => path_prefix, "subscribeMode" => subscribe_mode}) do
    %{path_prefix: path_prefix, subscribe_mode: subscribe_mode}
  end
end

defmodule Jellyfish.Component.Recording do
  @moduledoc """
  Options for the recording component.

  For the description of these options refer to [Jellyfish
  documentation](https://jellyfish-dev.github.io/jellyfish-docs/getting_started/components/recording).
  """

  @behaviour Jellyfish.Component.Deserializer

  alias Jellyfish.Component.HLS

  @enforce_keys []
  defstruct @enforce_keys ++ [credentials: nil, path_prefix: nil]

  @type t :: %__MODULE__{
          credentials: HLS.credentials() | nil,
          path_prefix: Path.t() | nil
        }

  @impl true
  def properties_from_json(%{"pathPrefix" => path_prefix}) do
    %{path_prefix: path_prefix}
  end
end

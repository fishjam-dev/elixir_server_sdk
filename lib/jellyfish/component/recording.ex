defmodule Jellyfish.Component.Recording do
  @moduledoc """
  Options for the recording component.

  For the description of these options refer to [Jellyfish
  documentation](https://jellyfish-dev.github.io/jellyfish-docs/getting_started/components/recording).
  """

  @behaviour Jellyfish.Component.Deserializer

  @enforce_keys []
  defstruct @enforce_keys ++ [credentials: nil, path_prefix: nil]

  @type credentials :: %{
          access_key_id: String.t(),
          secret_access_key: String.t(),
          region: String.t(),
          bucket: String.t()
        }

  @type t :: %__MODULE__{
          credentials: credentials(),
          path_prefix: Path.t()
        }

  @impl true
  def properties_from_json(%{"pathPrefix" => path_prefix}) do
    %{path_prefix: path_prefix}
  end
end

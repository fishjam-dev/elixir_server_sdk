defmodule Jellyfish.Component.File do
  @moduledoc """
  Options for the File component.

  For the description of these options refer to [Jellyfish
  documentation](https://jellyfish-dev.github.io/jellyfish-docs/getting_started/components/file).
  """

  @behaviour Jellyfish.Component.Deserializer

  @enforce_keys [:file_path]
  defstruct @enforce_keys ++ [framerate: nil]

  @type t :: %__MODULE__{
          file_path: String.t(),
          framerate: non_neg_integer() | nil
        }

  @impl true
  def properties_from_json(%{
        "filePath" => file_path,
        "framerate" => framerate
      }) do
    %{
      file_path: file_path,
      framerate: framerate
    }
  end
end

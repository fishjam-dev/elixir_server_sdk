defmodule Jellyfish.Component.File do
  @moduledoc """
  Options for the File component.

  For the description of these options refer to [Jellyfish
  documentation](https://jellyfish-dev.github.io/jellyfish-docs/getting_started/components/file).
  """

  @behaviour Jellyfish.Component.Deserializer

  @enforce_keys [:file_path]
  defstruct @enforce_keys ++
              []

  @type t :: %__MODULE__{
          file_path: String.t()
        }

  @impl true
  def properties_from_json(%{
        "filePath" => file_path
      }) do
    %{
      file_path: file_path
    }
  end
end

defmodule Fishjam.Component.File do
  @moduledoc """
  Options for the File component.

  For the description of these options refer to [Fishjam
  documentation](https://fishjam-dev.github.io/fishjam-docs/getting_started/components/file).
  """

  @behaviour Fishjam.Component.Deserializer

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

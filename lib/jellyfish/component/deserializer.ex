defmodule Jellyfish.Component.Deserializer do
  @moduledoc """
  Deserializes component metadata
  """
  @callback metadata_from_json(map()) :: map()
  @callback metadata_from_proto(map()) :: map()
end

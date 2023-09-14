defmodule Jellyfish.Component.Deserializer do
  @moduledoc false
  @callback metadata_from_json(map()) :: map()
end

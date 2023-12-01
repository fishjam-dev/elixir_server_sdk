defmodule Jellyfish.Component.Deserializer do
  @moduledoc false
  @callback properties_from_json(map()) :: map()
end

defmodule Jellyfish.Component.Deserializer do
  @moduledoc """
  Deserializes messeges to components modules
  """
  @callback from_json(map()) :: map()
  @callback from_proto(map()) :: map()
end

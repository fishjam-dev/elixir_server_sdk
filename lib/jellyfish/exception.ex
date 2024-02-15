defmodule Jellyfish.Exception do
  @moduledoc false

  defmodule StructureError do
    defexception [:message]

    @impl true
    def exception(structure) do
      msg = """
      Received server response or notification with unexpected structure.
      Make sure you are using correct combination of Jellyfish and SDK versions.
      Passed structure #{inspect(structure)}
      """

      %__MODULE__{message: msg}
    end
  end

  defmodule ProtocolPrefixError do
    defexception [:message]

    @impl true
    def exception(_opts) do
      msg = """
      Passed address starts with protocol prefix, like "http://" or "https://", which is undesired.
      To use SSL, set `secure?: true` option in `config.exs` or pass this option to called function.
      """

      %__MODULE__{message: msg}
    end
  end

  defmodule OptionsError do
    defexception [:message]

    @impl true
    def exception(_opts) do
      msg = """
      Passed component options that doesn't match function spec.
      Look closely on `Jellyfish.Room.add_component/3` spec.
      """

      %__MODULE__{message: msg}
    end
  end
end

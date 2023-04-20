defmodule Jellyfish.Exception do
  @moduledoc false

  defmodule StructureError do
    defexception [:message]

    @impl true
    def exception(_opts) do
      msg = """
      Received server response or notification with unexpected structure.
      Make sure you are using correct combination of Jellyfish and SDK versions.
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
      To use SSL, pass `secure?: true` option.
      """

      %__MODULE__{message: msg}
    end
  end
end

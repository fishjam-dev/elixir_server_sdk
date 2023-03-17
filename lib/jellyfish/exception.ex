defmodule Jellyfish.Exception do
  @moduledoc false

  defmodule ResponseStructureError do
    defexception [:message]

    @impl true
    def exception(_opts) do
      msg = """
      Received server response with unexpected structure.
      Make sure you are using correct combination of Jellyfish and SDK versions.
      """

      %__MODULE__{message: msg}
    end
  end
end

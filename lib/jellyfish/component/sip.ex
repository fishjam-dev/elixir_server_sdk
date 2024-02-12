defmodule Jellyfish.Component.SIP do
  @moduledoc """
  Options for the SIP component.

  For the description of these options refer to [Jellyfish
  documentation](https://jellyfish-dev.github.io/jellyfish-docs/getting_started/components/sip).
  """

  @behaviour Jellyfish.Component.Deserializer

  @enforce_keys [:registrar_credentials]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          registrar_credentials: %{
            address: String.t(),
            password: String.t(),
            username: String.t()
          }
        }

  @impl true
  def properties_from_json(%{
        "registrarCredentials" => %{
          "address" => address,
          "password" => password,
          "username" => username
        }
      }) do
    %{
      registrar_credentials: %{
        address: address,
        password: password,
        username: username
      }
    }
  end
end

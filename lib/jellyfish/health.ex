defmodule Fishjam.Health do
  @moduledoc """
  Utilities for managing the health of Fishjam instances.

  ## Examples
  ```
  iex> client = Fishjam.Client.new()
  iex> assert {:ok, %Fishjam.Health{
  ...>    status: :up,
  ...> }} = Fishjam.Health.check(client)
  ```
  """

  alias Fishjam.{Client, Utils}
  alias Fishjam.Exception.StructureError

  @enforce_keys [
    :status,
    :uptime,
    :distribution
  ]
  defstruct @enforce_keys

  @typedoc """
  The status of Fishjam or a specific service.
  """
  @type status :: :up | :down

  @typedoc """
  Stores a health report of Fishjam.

    * `:status` - overall status
    * `:uptime` - uptime in seconds
    * `:distribution` - distribution health report:
      - `:enabled` - whether distribution is enabled
      - `:node_status` - status of this Fishjam's node
      - `:nodes_in_cluster` - amount of nodes (including this Fishjam's node)
        in the distribution cluster
  """
  @type t :: %__MODULE__{
          status: status(),
          uptime: non_neg_integer(),
          distribution: %{
            enabled: boolean(),
            node_status: status(),
            nodes_in_cluster: non_neg_integer()
          }
        }

  @doc """
  Perform a health check of Fishjam.
  """
  @spec check(Client.t()) :: {:ok, t()} | {:error, atom() | String.t()}
  def check(client) do
    with {:ok, data} <- Utils.make_get_request!(client, "/health"),
         result <- from_json(data) do
      {:ok, result}
    end
  end

  @doc false
  @spec from_json(map()) :: t()
  def from_json(response) do
    case response do
      %{
        "status" => status,
        "uptime" => uptime,
        "distribution" => %{
          "enabled" => dist_enabled?,
          "nodeStatus" => node_status,
          "nodesInCluster" => nodes_in_cluster
        }
      } ->
        %__MODULE__{
          status: status_atom(status),
          uptime: uptime,
          distribution: %{
            enabled: dist_enabled?,
            node_status: status_atom(node_status),
            nodes_in_cluster: nodes_in_cluster
          }
        }

      unknown_structure ->
        raise StructureError, unknown_structure
    end
  end

  defp status_atom("UP"), do: :up
  defp status_atom("DOWN"), do: :down
end

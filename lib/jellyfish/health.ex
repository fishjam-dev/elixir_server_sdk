defmodule Jellyfish.Health do
  @moduledoc """
  Utilities for managing the health of Jellyfish instances.

  ## Examples
  ```
  iex> client = Jellyfish.Client.new()
  iex> assert {:ok, %Jellyfish.Health{
  ...>    status: :up,
  ...> }} = Jellyfish.Health.check(client)
  ```
  """

  alias Jellyfish.{Client, Utils}
  alias Jellyfish.Exception.StructureError

  @enforce_keys [
    :status,
    :uptime,
    :distribution
  ]
  defstruct @enforce_keys

  @typedoc """
  The status of Jellyfish or a specific service.
  """
  @type status :: :up | :down

  @typedoc """
  Stores a health report of Jellyfish.

    * `:status` - overall status
    * `:uptime` - uptime in seconds
    * `:distribution` - distribution health report:
      - `:enabled` - whether distribution is enabled
      - `:node_status` - status of this Jellyfish's node
      - `:nodes_in_cluster` - amount of nodes (including this Jellyfish's node)
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
  Perform a health check of Jellyfish.
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

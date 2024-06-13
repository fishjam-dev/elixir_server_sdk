defmodule Fishjam.Health do
  @moduledoc """
  Utilities for managing the health of Fishjam instances.

  ## Examples
  ```
  iex> client = Fishjam.Client.new()
  iex> assert {:ok, %Fishjam.Health{
  ...>    local_status: %{status: "UP"},
  ...> }} = Fishjam.Health.check(client)
  ```
  """

  alias Fishjam.Client
  alias Fishjam.Utils

  @enforce_keys [
    :local_status,
    :nodes_status,
    :distribution_enabled,
    :nodes_in_cluster
  ]
  defstruct @enforce_keys

  @typedoc """
  The status of Fishjam or a specific node.

    * `:git_commit` - git commit hash on node
    * `:node_name` - node name
    * `:status` - can be "UP" or "DOWN"
    * `:uptime` - uptime in seconds
    * `:version` - version running on node
  """
  @type node_status :: %{
          git_commit: String.t(),
          node_name: node(),
          status: String.t(),
          uptime: non_neg_integer(),
          version: String.t()
        }

  @typedoc """
  Stores a health report of Fishjam.

    * `:local_status` - overall status for local node
    * `:local_status` - overall status for all nodes in cluster
    * `:distribution_enabled` - whether distribution is enabled
    * `:nodes_in_cluster` - amount of nodes (including this Fishjam's node)
  """
  @type t :: %__MODULE__{
          local_status: node_status(),
          nodes_status: list(node_status()),
          distribution_enabled: boolean(),
          nodes_in_cluster: non_neg_integer()
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
    %__MODULE__{
      local_status: node_status(response["localStatus"]),
      nodes_status: Enum.map(Map.get(response, "nodesStatus", []), &node_status/1),
      distribution_enabled: response["distributionEnabled"],
      nodes_in_cluster: response["nodesInCluster"]
    }
  end

  defp node_status(node_status) do
    %{
      git_commit: node_status["gitCommit"],
      node_name: node_status["nodeName"],
      status: node_status["status"],
      uptime: node_status["uptime"],
      version: node_status["version"]
    }
  end
end

defmodule Fishjam.HealthTest do
  use ExUnit.Case

  doctest Fishjam.Health

  alias Fishjam.{Client, Health}

  setup do
    %{client: Client.new()}
  end

  test "healthcheck", %{client: client} do
    assert {:ok, health} = Health.check(client)

    assert %Health{
             local_status: %{
               status: "UP"
             },
             nodes_status: _,
             distribution_enabled: _,
             nodes_in_cluster: _
           } = health
  end
end

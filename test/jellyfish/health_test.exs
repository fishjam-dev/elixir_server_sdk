defmodule Jellyfish.HealthTest do
  use ExUnit.Case

  doctest Jellyfish.Health

  alias Jellyfish.{Client, Health}

  setup do
    %{client: Client.new()}
  end

  test "healthcheck", %{client: client} do
    assert {:ok, health} = Health.check(client)

    assert %Health{
             status: :up,
             uptime: _uptime,
             distribution: _distribution_health
           } = health
  end
end

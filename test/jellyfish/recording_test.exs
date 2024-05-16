defmodule Fishjam.RecordingTest do
  use ExUnit.Case
  doctest Fishjam.Recording

  alias Fishjam.{Client, Recording}

  setup do
    %{client: Client.new()}
  end

  test "list recordings", %{client: client} do
    assert {:ok, []} = Recording.get_list(client)
  end

  test "delete", %{client: client} do
    assert {:error, _reason} = Recording.delete(client, "wrong_id")
  end
end

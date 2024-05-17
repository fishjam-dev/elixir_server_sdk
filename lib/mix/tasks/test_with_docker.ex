defmodule Mix.Tasks.TestWithDocker do
  @moduledoc """
  Test the SDK with Fishjam running in Docker
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    if System.find_executable("docker") do
      IO.puts("Running tests using Docker. To run tests without Docker call \"mix test.local\"")

      docker_compose_prefix = ["docker", "compose", "-f", "docker-compose-test.yaml"]

      stream_command(docker_compose_prefix ++ ["pull"])

      stream_command(
        docker_compose_prefix ++ ["up", "--remove-orphans", "test", "--exit-code-from", "test"]
      )

      stream_command(docker_compose_prefix ++ ["down"])
    else
      IO.puts("Running tests inside docker container ...")

      Mix.Task.run("test", args)
    end
  end

  defp stream_command(cmd) do
    port =
      Port.open({:spawn, Enum.join(cmd, " ")}, [
        {:line, 1024},
        :use_stdio,
        :stderr_to_stdout,
        :exit_status
      ])

    receive_and_print(port)
  end

  defp receive_and_print(port) do
    receive do
      {^port, {:data, {:eol, line}}} ->
        IO.puts(line)
        receive_and_print(port)

      {^port, {:data, data}} ->
        IO.puts(data)
        receive_and_print(port)

      {^port, {:exit_status, exit_status}} ->
        IO.puts("Docker command exited with status code: #{exit_status}")
    end
  end
end

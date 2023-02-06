defmodule Jellyfish.SDK.Utils do
  @moduledoc false

  alias Tesla.Env

  @doc false
  def translate_error_response({:ok, %Env{body: %{"errors" => error}}}) do
    {:error, "Request failed: #{error}"}
  end

  @doc false
  def translate_error_response({:error, reason}) do
    {:error, "Internal error: #{inspect(reason)}"}
  end
end

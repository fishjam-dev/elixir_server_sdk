defmodule Jellyfish.SDK.Utils do
  @moduledoc false

  alias Tesla.Env

  @spec translate_error_response({:error, any()}) :: {:error, String.t()}
  def translate_error_response({:ok, %Env{body: %{"errors" => error}}}) do
    {:error, "Request failed: #{error}"}
  end

  def translate_error_response({:ok, %Env{body: body}}) do
    {:error, "Received unexpected response: #{inspect({body})}"}
  end

  def translate_error_response({:error, reason}) do
    {:error, "Internal error: #{inspect(reason)}"}
  end
end

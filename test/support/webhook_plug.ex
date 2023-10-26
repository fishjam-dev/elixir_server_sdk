defmodule WebHookPlug do
  @moduledoc false
  import Plug.Conn
  alias Jellyfish.WebhookNotifier
  alias Phoenix.PubSub

  @pubsub Jellyfish.PubSub

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, [])
    notification = Jason.decode!(body)

    notification = WebhookNotifier.receive(notification)

    :ok = PubSub.broadcast(@pubsub, "webhook", {:webhook, notification})

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "OK")
  end
end

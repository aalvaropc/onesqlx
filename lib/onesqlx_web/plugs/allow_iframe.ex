defmodule OnesqlxWeb.Plugs.AllowIframe do
  @moduledoc """
  Overrides the default Content-Security-Policy to allow embedding in iframes.

  Replaces `frame-ancestors 'self'` with `frame-ancestors *` and removes
  the legacy `x-frame-options` header.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> delete_resp_header("x-frame-options")
    |> put_resp_header(
      "content-security-policy",
      "base-uri 'self'; frame-ancestors *;"
    )
  end
end

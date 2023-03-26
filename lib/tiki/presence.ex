defmodule Tiki.Presence do
  use Phoenix.Presence,
    otp_app: :tiki,
    pubsub_server: Tiki.PubSub
end

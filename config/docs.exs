import Config

import_config "dev.exs"

config :phoenix_live_view,
  debug_heex_annotations: false,
  debug_attributes: false,
  enable_expensive_runtime_checks: false

config :mdex_native, syntax_highlighter: :lumis

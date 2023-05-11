import Config

config :jellyfish_server_sdk,
  divo: "docker-compose.yaml",
  divo_wait: [dwell: 700, max_tries: 50]

import_config "#{config_env()}.exs"

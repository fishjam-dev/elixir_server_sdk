import Config

config :jellyfish_server_sdk,
  divo: "docker-compose-integration.yaml",
  divo_wait: [dwell: 1_500, max_tries: 50]

import_config "#{config_env()}.exs"

import Config

config :jellyfish_server_sdk,
  server_address: "jellyfish:5002",
  server_api_token: "development",
  divo: "docker-compose-integration.yaml",
  divo_wait: [dwell: 1_500, max_tries: 50]

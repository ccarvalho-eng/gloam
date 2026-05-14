import Config

config :gloam,
  auth_secret: System.get_env("GLOAM_AUTH_SECRET") || "local-development-gloam-secret",
  storage_path: System.get_env("GLOAM_STORAGE_PATH") || "priv/gloam/storage"

config :gloam, :http,
  enabled: true,
  ip: :loopback,
  port: String.to_integer(System.get_env("GLOAM_PORT") || "4000")

env_config = "#{config_env()}.exs"

if File.exists?(Path.join(__DIR__, env_config)) do
  import_config env_config
end

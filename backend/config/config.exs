# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :todo_api,
  generators: [timestamp_type: :utc_datetime]

config :todo_api, :todos,
  repository: TodoApi.Todos.Repositories.MongoRepository,
  cache: TodoApi.Todos.Caches.ValkeyCache,
  cache_ttl_seconds: 120

config :todo_api, :mongo,
  url: "mongodb://localhost:27017/todo_api_dev",
  pool_size: 10

config :todo_api, :ensure_mongo_indexes, true

config :todo_api, :valkey,
  host: "localhost",
  port: 6379,
  password: nil,
  database: 0

# Configure the endpoint
config :todo_api, TodoApiWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: TodoApiWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: TodoApi.PubSub,
  live_view: [signing_salt: "8jxEZYW+"]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

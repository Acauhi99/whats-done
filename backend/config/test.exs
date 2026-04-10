import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :todo_api, TodoApiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "JcIysub0C+wZqP+93b5jPCY/hBghU1RSj8AjRIqYLpKemB9nZ829mzEPghTzrB6I",
  server: false

config :todo_api, :start_external_clients, false
config :todo_api, :ensure_mongo_indexes, false

config :todo_api, :todos,
  repository: TodoApi.Todos.Repositories.InMemoryRepository,
  cache: TodoApi.Todos.Caches.NoopCache

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

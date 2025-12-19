import Config

# Token management configuration for tests
# Use shorter lifetime and more frequent checks for faster, more reliable tests
config :just_travel_test, JustTravelTest.Tokens,
  max_active_tokens: 100,
  token_lifetime_minutes: 1,  # 1 minute for faster test execution
  check_interval_seconds: 10  # Check every 10 seconds in tests

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :just_travel_test, JustTravelTest.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "just_travel_test_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :just_travel_test, JustTravelTestWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "/cVLk7aSZA1kksjcwEYPNqxrbEpE0tml+iHOxJBnDV9vJ8j3UHbNR6hhTmSURf96",
  server: false

# In test we don't send emails
config :just_travel_test, JustTravelTest.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

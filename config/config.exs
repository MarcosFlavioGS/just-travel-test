# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :just_travel_test,
  ecto_repos: [JustTravelTest.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :just_travel_test, JustTravelTestWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: JustTravelTestWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: JustTravelTest.PubSub,
  live_view: [signing_salt: "wPALFgd7"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :just_travel_test, JustTravelTest.Mailer, adapter: Swoosh.Adapters.Local

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Token management configuration
config :just_travel_test, JustTravelTest.Tokens,
  max_active_tokens: 100,
  token_lifetime_minutes: 2,
  check_interval_seconds: 30

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

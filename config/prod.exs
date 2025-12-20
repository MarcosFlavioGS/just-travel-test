import Config

# Configures Swoosh API Client
config :swoosh, api_client: Swoosh.ApiClient.Req

# Disable Swoosh Local Memory Storage
config :swoosh, local: false

# Do not print debug messages in production
config :logger, level: :info

# Rate limiting configuration
config :just_travel_test, :enable_rate_limiting, true
config :just_travel_test, :rate_limit_per_minute, 100

# Production logging configuration
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :token_id, :user_id, :event, :status]

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.

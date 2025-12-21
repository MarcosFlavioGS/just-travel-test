defmodule JustTravelTestWeb.Router do
  use JustTravelTestWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Health check endpoint (no authentication required)
  get "/health", JustTravelTestWeb.Health.HealthController, :check

  scope "/api", JustTravelTestWeb do
    pipe_through :api

    post "/tokens/activate", Token.TokenController, :activate
    get "/tokens", Token.TokenController, :index
    get "/tokens/:token_id", Token.TokenController, :show
    get "/tokens/:token_id/usages", Token.TokenController, :usages
    delete "/tokens/active", Token.TokenController, :clear_active
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:just_travel_test, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: JustTravelTestWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

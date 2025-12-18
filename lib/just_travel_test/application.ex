defmodule JustTravelTest.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      JustTravelTestWeb.Telemetry,
      JustTravelTest.Repo,
      {DNSCluster, query: Application.get_env(:just_travel_test, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: JustTravelTest.PubSub},
      # Start a worker by calling: JustTravelTest.Worker.start_link(arg)
      # {JustTravelTest.Worker, arg},
      # Start to serve requests, typically the last entry
      JustTravelTestWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: JustTravelTest.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    JustTravelTestWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

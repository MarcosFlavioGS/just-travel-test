defmodule JustTravelTestWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      sum("phoenix.socket_drain.count"),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("just_travel_test.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("just_travel_test.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("just_travel_test.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("just_travel_test.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("just_travel_test.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # Token Management Metrics
      counter("just_travel_test.tokens.activation.success",
        description: "Number of successful token activations"
      ),
      counter("just_travel_test.tokens.activation.failure",
        description: "Number of failed token activations",
        tags: [:reason]
      ),
      summary("just_travel_test.tokens.activation.success.duration",
        unit: {:native, :millisecond},
        description: "Duration of successful token activations"
      ),
      summary("just_travel_test.tokens.activation.failure.duration",
        unit: {:native, :millisecond},
        description: "Duration of failed token activations"
      ),
      counter("just_travel_test.tokens.release.success",
        description: "Number of successful token releases"
      ),
      counter("just_travel_test.tokens.release.failure",
        description: "Number of failed token releases",
        tags: [:reason]
      ),
      summary("just_travel_test.tokens.release.success.duration",
        unit: {:native, :millisecond},
        description: "Duration of successful token releases"
      ),
      counter("just_travel_test.tokens.expiration.success",
        description: "Number of successful expiration checks"
      ),
      counter("just_travel_test.tokens.expiration.failure",
        description: "Number of failed expiration checks"
      ),
      summary("just_travel_test.tokens.expiration.success.duration",
        unit: {:native, :millisecond},
        description: "Duration of expiration checks"
      ),
      last_value("just_travel_test.tokens.expiration.success.count",
        description: "Number of tokens released in last expiration check"
      ),
      counter("just_travel_test.tokens.manager.check",
        description: "Number of manager periodic checks",
        tags: [:status]
      ),
      summary("just_travel_test.tokens.manager.check.duration",
        unit: {:native, :millisecond},
        description: "Duration of manager checks"
      ),
      last_value("just_travel_test.tokens.manager.check.released_count",
        description: "Number of tokens released in last manager check"
      )
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {JustTravelTestWeb, :count_users, []}
    ]
  end
end

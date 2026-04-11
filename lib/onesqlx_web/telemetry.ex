defmodule OnesqlxWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000},
      {TelemetryMetricsPrometheus.Core, metrics: prometheus_metrics(), name: :onesqlx_prometheus}
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
      summary("onesqlx.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("onesqlx.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("onesqlx.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("onesqlx.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("onesqlx.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # Oban Job Metrics
      summary("oban.job.stop.duration",
        tags: [:worker, :queue],
        unit: {:native, :millisecond},
        description: "Duration of completed Oban jobs"
      ),
      summary("oban.job.exception.duration",
        tags: [:worker, :queue],
        unit: {:native, :millisecond},
        description: "Duration of failed Oban jobs"
      ),
      counter("oban.job.stop.duration",
        tags: [:worker, :queue, :state],
        description: "Count of completed Oban jobs by state"
      ),
      counter("oban.job.exception.duration",
        tags: [:worker],
        description: "Count of failed Oban jobs"
      ),

      # Custom Business Metrics
      last_value("onesqlx.scheduled_queries.active.count",
        description: "Number of enabled scheduled queries"
      ),
      last_value("onesqlx.data_sources.total.count",
        description: "Number of configured data sources"
      )
    ]
  end

  @doc false
  def prometheus_metrics do
    [
      # Phoenix request counter
      counter("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        description: "HTTP request count by route"
      ),
      counter("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        description: "HTTP exception count by route"
      ),

      # Database query counter
      counter("onesqlx.repo.query.total_time",
        description: "Database query count"
      ),

      # Oban counters
      counter("oban.job.stop.duration",
        tags: [:worker, :queue, :state],
        description: "Completed Oban jobs count"
      ),
      counter("oban.job.exception.duration",
        tags: [:worker],
        description: "Failed Oban jobs count"
      ),

      # VM gauges
      last_value("vm.memory.total", unit: {:byte, :kilobyte}),
      last_value("vm.total_run_queue_lengths.total"),
      last_value("vm.total_run_queue_lengths.cpu"),
      last_value("vm.total_run_queue_lengths.io"),

      # Custom business gauges
      last_value("onesqlx.scheduled_queries.active.count",
        description: "Number of enabled scheduled queries"
      ),
      last_value("onesqlx.data_sources.total.count",
        description: "Number of configured data sources"
      )
    ]
  end

  defp periodic_measurements do
    [
      {__MODULE__, :measure_scheduled_queries, []},
      {__MODULE__, :measure_data_sources, []}
    ]
  end

  @doc false
  def measure_scheduled_queries do
    import Ecto.Query

    count =
      Onesqlx.Repo.aggregate(from(sq in "scheduled_queries", where: sq.enabled == true), :count)

    :telemetry.execute([:onesqlx, :scheduled_queries, :active], %{count: count})
  rescue
    _ -> :ok
  end

  @doc false
  def measure_data_sources do
    import Ecto.Query
    count = Onesqlx.Repo.aggregate(from(_ds in "data_sources"), :count)
    :telemetry.execute([:onesqlx, :data_sources, :total], %{count: count})
  rescue
    _ -> :ok
  end
end

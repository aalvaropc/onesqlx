defmodule Onesqlx.Sample do
  @moduledoc """
  Installs a self-contained sample data source so a fresh instance has
  something to explore without connecting a database first.

  The dataset (a small e-commerce store) lives in an `onesqlx_sample`
  schema inside OneSQLx's own database, which keeps the demo working on
  any deployment without extra infrastructure.

  ## Why a dedicated PostgreSQL role

  The sample data source points at the application's own database, so it
  connects as a purpose-made role that is granted `SELECT` **only** on
  the sample schema. Tables created by Ecto migrations grant nothing to
  other roles, so even someone who repoints this data source at another
  schema reads nothing: no users, no API tokens, no encrypted
  credentials. Installation is skipped with a warning when the database
  user cannot create roles (common on managed PostgreSQL).
  """

  require Logger

  alias Onesqlx.Accounts.Scope
  alias Onesqlx.Catalog.SyncWorker
  alias Onesqlx.Dashboards
  alias Onesqlx.DataSources
  alias Onesqlx.Repo
  alias Onesqlx.SavedQueries

  @schema "onesqlx_sample"
  @role "onesqlx_sample"
  @data_source_name "Sample Data"
  @dashboard_title "Sample — E-commerce overview"

  @doc """
  Installs the sample schema, data source, saved queries, and dashboard
  for the given scope.

  Idempotent: returns `{:ok, :already_installed}` when the sample data
  source already exists in the workspace. Returns `{:error, reason}`
  when the database user lacks the privileges to set it up.
  """
  def install(%Scope{} = scope, opts \\ []) do
    if installed?(scope) do
      {:ok, :already_installed}
    else
      do_install(scope, opts)
    end
  end

  @doc "Whether the workspace already has the sample data source."
  def installed?(%Scope{} = scope) do
    scope |> DataSources.list_data_sources() |> Enum.any?(&(&1.name == @data_source_name))
  end

  defp do_install(scope, opts) do
    password = 32 |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower)

    with :ok <- create_dataset(),
         :ok <- create_role(password),
         {:ok, data_source} <- register_data_source(scope, password) do
      queries = create_saved_queries(scope, data_source)
      {:ok, dashboard} = create_dashboard(scope, queries)

      if Keyword.get(opts, :sync_catalog, true) do
        SyncWorker.enqueue(data_source.id)
      end

      {:ok, %{data_source: data_source, dashboard: dashboard, queries: queries}}
    end
  end

  # ── Dataset ────────────────────────────────────────────────────────
  # Generated entirely in SQL from generate_series and deterministic
  # arithmetic, so every install produces the same store.

  defp create_dataset do
    Repo.query!("CREATE SCHEMA IF NOT EXISTS #{@schema}")

    Repo.query!("""
    CREATE TABLE IF NOT EXISTS #{@schema}.customers (
      id integer PRIMARY KEY,
      name text NOT NULL,
      email text NOT NULL,
      country text NOT NULL,
      signup_date date NOT NULL
    )
    """)

    Repo.query!("""
    CREATE TABLE IF NOT EXISTS #{@schema}.products (
      id integer PRIMARY KEY,
      name text NOT NULL,
      category text NOT NULL,
      price numeric(10,2) NOT NULL
    )
    """)

    Repo.query!("""
    CREATE TABLE IF NOT EXISTS #{@schema}.orders (
      id integer PRIMARY KEY,
      customer_id integer NOT NULL REFERENCES #{@schema}.customers(id),
      ordered_at timestamptz NOT NULL,
      status text NOT NULL
    )
    """)

    Repo.query!("""
    CREATE TABLE IF NOT EXISTS #{@schema}.order_items (
      id integer PRIMARY KEY,
      order_id integer NOT NULL REFERENCES #{@schema}.orders(id),
      product_id integer NOT NULL REFERENCES #{@schema}.products(id),
      quantity integer NOT NULL,
      unit_price numeric(10,2) NOT NULL
    )
    """)

    if empty?("products"), do: insert_dataset()
    :ok
  end

  defp empty?(table) do
    %{rows: [[count]]} = Repo.query!("SELECT count(*) FROM #{@schema}.#{table}")
    count == 0
  end

  defp insert_dataset do
    Repo.query!("""
    INSERT INTO #{@schema}.products (id, name, category, price)
    SELECT i,
           (ARRAY['Aurora','Nimbus','Vertex','Lumen','Cobalt','Quartz','Ember','Onyx'])[1 + (i % 8)]
             || ' ' ||
             (ARRAY['Headphones','Keyboard','Monitor','Chair','Lamp','Backpack','Mug','Notebook'])[1 + ((i / 8) % 8)],
           (ARRAY['Audio','Peripherals','Displays','Furniture','Lighting','Accessories'])[1 + (i % 6)],
           round(((i * 7919) % 48000)::numeric / 100 + 9.99, 2)
    FROM generate_series(1, 40) i
    """)

    Repo.query!("""
    INSERT INTO #{@schema}.customers (id, name, email, country, signup_date)
    SELECT i,
           (ARRAY['Ana','Luis','Marta','Diego','Sofía','Carlos','Elena','Javier','Lucía','Pablo','Nuria','Andrés'])[1 + (i % 12)]
             || ' ' ||
             (ARRAY['García','Rojas','Fernández','Molina','Vargas','Castro','Silva','Ortega','Ramos','Peña'])[1 + ((i / 12) % 10)],
           'customer' || i || '@example.com',
           (ARRAY['Peru','Chile','Mexico','Spain','Colombia','Argentina'])[1 + ((i * 5) % 6)],
           DATE '2025-01-01' + ((i * 13) % 500)
    FROM generate_series(1, 150) i
    """)

    Repo.query!("""
    INSERT INTO #{@schema}.orders (id, customer_id, ordered_at, status)
    SELECT i,
           1 + ((i * 37) % 150),
           now() - (((i * 7919) % 360) || ' days')::interval
                 - (((i * 13) % 24) || ' hours')::interval,
           CASE (i * 7) % 10
             WHEN 0 THEN 'cancelled'
             WHEN 1 THEN 'pending'
             WHEN 2 THEN 'refunded'
             WHEN 3 THEN 'shipped'
             ELSE 'delivered'
           END
    FROM generate_series(1, 1200) i
    """)

    Repo.query!("""
    INSERT INTO #{@schema}.order_items (id, order_id, product_id, quantity, unit_price)
    SELECT row_number() OVER (ORDER BY x.order_id, x.n),
           x.order_id, x.product_id, x.quantity, p.price
    FROM (
      SELECT o.id AS order_id,
             n,
             1 + ((o.id * 31 + n) % 40) AS product_id,
             1 + ((o.id + n) % 3) AS quantity
      FROM #{@schema}.orders o,
           LATERAL generate_series(1, 1 + (o.id % 3)) n
    ) x
    JOIN #{@schema}.products p ON p.id = x.product_id
    """)
  end

  # ── Role ───────────────────────────────────────────────────────────

  defp create_role(password) do
    database = Repo.config()[:database]

    Repo.query!("""
    DO $sample$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '#{@role}') THEN
        CREATE ROLE #{@role} LOGIN PASSWORD '#{password}';
      ELSE
        ALTER ROLE #{@role} LOGIN PASSWORD '#{password}';
      END IF;
    END
    $sample$
    """)

    # SELECT on the sample schema only. App tables grant nothing to this
    # role, so it cannot read them even if pointed at another schema.
    Repo.query!(~s(GRANT CONNECT ON DATABASE "#{database}" TO #{@role}))
    Repo.query!("GRANT USAGE ON SCHEMA #{@schema} TO #{@role}")
    Repo.query!("GRANT SELECT ON ALL TABLES IN SCHEMA #{@schema} TO #{@role}")
    :ok
  rescue
    error in Postgrex.Error ->
      Logger.warning("""
      Skipping sample data: could not create the '#{@role}' PostgreSQL role \
      (#{Exception.message(error)}). The database user needs CREATEROLE. \
      Connect a data source manually instead.\
      """)

      {:error, :insufficient_privileges}
  end

  # ── Application records ────────────────────────────────────────────

  defp register_data_source(scope, password) do
    config = Repo.config()

    DataSources.create_data_source(scope, %{
      name: @data_source_name,
      host: config[:hostname] || "localhost",
      port: config[:port] || 5432,
      database_name: config[:database],
      username: @role,
      password: password,
      ssl_enabled: false,
      read_only: true,
      status: "pending"
    })
  end

  defp create_saved_queries(scope, data_source) do
    Map.new(sample_queries(), fn {key, attrs} ->
      {:ok, query} =
        SavedQueries.create_saved_query(
          scope,
          Map.merge(attrs, %{
            "data_source_id" => data_source.id,
            "user_id" => scope.user.id,
            "tags" => ["sample"]
          })
        )

      {key, query}
    end)
  end

  defp sample_queries do
    %{
      revenue_total: %{
        "title" => "Total revenue",
        "description" => "Revenue from delivered and shipped orders.",
        "sql" => """
        SELECT round(sum(oi.quantity * oi.unit_price), 2) AS revenue
        FROM onesqlx_sample.order_items oi
        JOIN onesqlx_sample.orders o ON o.id = oi.order_id
        WHERE o.status IN ('delivered', 'shipped');\
        """
      },
      revenue_by_month: %{
        "title" => "Revenue by month",
        "description" => "Monthly revenue over the last year.",
        "sql" => """
        SELECT to_char(date_trunc('month', o.ordered_at), 'YYYY-MM') AS month,
               round(sum(oi.quantity * oi.unit_price), 2) AS revenue
        FROM onesqlx_sample.orders o
        JOIN onesqlx_sample.order_items oi ON oi.order_id = o.id
        WHERE o.status IN ('delivered', 'shipped')
        GROUP BY 1
        ORDER BY 1;\
        """
      },
      top_products: %{
        "title" => "Top products by revenue",
        "description" => "The ten products that bring in the most money.",
        "sql" => """
        SELECT p.name AS product,
               round(sum(oi.quantity * oi.unit_price), 2) AS revenue
        FROM onesqlx_sample.order_items oi
        JOIN onesqlx_sample.products p ON p.id = oi.product_id
        GROUP BY 1
        ORDER BY revenue DESC
        LIMIT 10;\
        """
      },
      orders_by_status: %{
        "title" => "Orders by status",
        "description" => "How orders are distributed across statuses.",
        "sql" => """
        SELECT status, count(*) AS orders
        FROM onesqlx_sample.orders
        GROUP BY 1
        ORDER BY orders DESC;\
        """
      },
      recent_orders: %{
        "title" => "Recent orders",
        "description" => "The latest orders with customer and total.",
        "sql" => """
        SELECT o.id,
               c.name AS customer,
               c.country,
               o.status,
               round(sum(oi.quantity * oi.unit_price), 2) AS total,
               o.ordered_at
        FROM onesqlx_sample.orders o
        JOIN onesqlx_sample.customers c ON c.id = o.customer_id
        JOIN onesqlx_sample.order_items oi ON oi.order_id = o.id
        GROUP BY o.id, c.name, c.country, o.status, o.ordered_at
        ORDER BY o.ordered_at DESC
        LIMIT 25;\
        """
      }
    }
  end

  defp create_dashboard(scope, queries) do
    {:ok, dashboard} =
      Dashboards.create_dashboard(scope, %{
        title: @dashboard_title,
        description: "Built from the sample dataset. Safe to edit or delete."
      })

    cards = [
      {queries.revenue_total, "kpi", %{"span" => 1, "prefix" => "$"}},
      {queries.orders_by_status, "pie", %{"span" => 1}},
      {queries.revenue_by_month, "line", %{"span" => 2}},
      {queries.top_products, "bar", %{"span" => 2}},
      {queries.recent_orders, "table", %{"span" => 2}}
    ]

    Enum.each(cards, fn {query, type, config} ->
      {:ok, _card} =
        Dashboards.add_card(scope, dashboard, %{
          saved_query_id: query.id,
          type: type,
          title: query.title,
          config: config
        })
    end)

    {:ok, dashboard}
  end
end

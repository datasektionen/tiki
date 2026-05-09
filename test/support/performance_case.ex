defmodule Tiki.PerformanceCase do
  @moduledoc """
  Case template for performance and concurrency tests.

  Uses real database transactions (no Ecto sandbox) so that PostgreSQL
  isolation and locking behaviour matches production.

  ## Scale

  Set `PERF_SCALE` to multiply all scenario capacities (and therefore buyer
  counts) without touching test code:

      mix test --only performance               # PERF_SCALE=1 (scenario defaults)
      PERF_SCALE=50 mix test --only performance # 50× all capacities

  ## Setup

  Use `setup_event/1` with either a shorthand capacity or a full scenario spec:

      # shorthand — single batch, single ticket type
      setup_event(capacity: 100)

      # full spec from Scenarios module
      setup_event(spec: Tiki.Performance.Scenarios.multi_date())

  The returned map always contains `:event`, `:batches`, `:buyer_plan`, and
  `:cleanup`. Pass `:cleanup` directly to `on_exit/1`.
  """

  use ExUnit.CaseTemplate

  # Fixed admin user for all performance/benchmark runs. Inserted on demand with
  # on_conflict: :nothing so it survives across test runs without fixture overhead.
  @perf_admin_id -1

  def perf_admin_id, do: @perf_admin_id

  using do
    quote do
      import Ecto.Query
      import Tiki.PerformanceCase

      alias Tiki.Repo
      alias Tiki.Orders

      alias Tiki.Performance.Scenarios
    end
  end

  alias Tiki.Orders

  setup do
    # Switch pool to :auto so all spawned processes can acquire DB connections without explicit checkout.
    # Restored to :manual in on_exit so normal sandboxed tests are unaffected.
    Ecto.Adapters.SQL.Sandbox.mode(Tiki.Repo, :auto)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.mode(Tiki.Repo, :manual) end)
    :ok
  end

  @doc """
  Scale multiplier for all scenario capacities.
  """
  def perf_scale do
    case System.get_env("PERF_SCALE") do
      nil -> 1
      val -> String.to_integer(val)
    end
  end

  @doc """
  Creates an event from a scenario spec (or a capacity shorthand) and returns:

      %{
        event:      %Event{},
        batches:    %{"Batch Name" => %{batch: _, ticket_types: %{key: _}, batches: %{}}},
        buyer_plan: [%{ticket_type: _, batch: "name", key: :atom}, ...],
        cleanup:    fn -> ... end
      }

  `buyer_plan` is a pre-shuffled list of individual purchase attempts derived
  from each ticket type's `weight` and the batch `capacity × load_factor`.
  Pass it to `Enum.map/Task.async` to fire all buyers simultaneously.

  `cleanup` removes every record created here (team, event, batches, ticket
  types, orders, tickets, admin user) in FK-safe order. Pass it to `on_exit/1`.
  """
  def setup_event(opts \\ []) do
    spec =
      case Keyword.fetch(opts, :spec) do
        {:ok, spec} ->
          spec

        :error ->
          capacity = Keyword.get(opts, :capacity, 10)

          %{
            load_factor: 2.0,
            batches: [
              %{
                name: "General",
                capacity: capacity,
                ticket_types: [
                  %{key: :general, name: "General Admission", price: 0, weight: 1}
                ]
              }
            ]
          }
      end

    setup_from_spec(spec)
  end

  # ---------------------------------------------------------------------------
  # Load-running helpers
  # ---------------------------------------------------------------------------

  @doc """
  Fires every entry in `plan` as a concurrent `reserve_tickets` call.
  Returns `{wall_micros, [{plan_entry, result}], per_request_micros}`.

  Options:
    - `:cancel_prob` — probability [0,1) that a successful reservation is immediately cancelled
    - `:pay_prob`    — probability [0,1) that a successful reservation is immediately paid via
      `Orders.init_checkout/3` (mutually exclusive with cancel; combined probability should be ≤ 1)
    - `:timeout`     — per-task await timeout in ms (default 60_000)
  """
  def run_buyer_plan(event_id, plan, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 60_000)
    cancel_prob = Keyword.get(opts, :cancel_prob, 0.0)
    pay_prob = Keyword.get(opts, :pay_prob, 0.0)

    tasks =
      Enum.map(plan, fn %{ticket_type: tt} = entry ->
        {entry,
         Task.async(fn ->
           receive do
             :go ->
               {req_micros, result} =
                 :timer.tc(fn -> Orders.reserve_tickets(event_id, %{tt.id => 1}, nil) end)

               with {:ok, order} <- result do
                 r = :rand.uniform()

                 cond do
                   r < cancel_prob ->
                     Orders.maybe_cancel_order(order.id)

                   r < cancel_prob + pay_prob ->
                     # if price == 0 this immediately marks order as paid
                     Orders.init_checkout(order, nil, perf_admin_id())

                   true ->
                     :ok
                 end
               end

               {req_micros, result}
           end
         end)}
      end)

    {wall_micros, task_results} =
      :timer.tc(fn ->
        Enum.map(tasks, fn {_entry, task} ->
          # start all the tasks
          send(task.pid, :go)
          task
        end)
        |> Task.await_many(timeout)
      end)

    {zipped, timings} =
      Enum.zip(tasks, task_results)
      |> Enum.map_reduce([], fn {{entry, _task}, {req_micros, result}}, acc ->
        {{entry, result}, [req_micros | acc]}
      end)

    {wall_micros, zipped, Enum.reverse(timings)}
  end

  @doc """
  Fires `n` concurrent reservation attempts for a single ticket type.
  Returns `{wall_micros, [result], per_request_micros}`.
  """
  def run_wave(event_id, ticket_type, n, timeout \\ 60_000) do
    tasks =
      1..n
      |> Enum.map(fn _ ->
        Task.async(fn ->
          receive do
            :go ->
              :timer.tc(fn -> Orders.reserve_tickets(event_id, %{ticket_type.id => 1}, nil) end)
          end
        end)
      end)

    {wall_micros, pairs} =
      :timer.tc(fn ->
        Enum.map(tasks, fn task ->
          send(task.pid, :go)
          task
        end)
        |> Task.await_many(timeout)
      end)

    {timings, results} = Enum.unzip(pairs)
    {wall_micros, results, timings}
  end

  @doc """
  Returns the p-th percentile of a list of numeric values.
  """
  def percentile(values, p) do
    sorted = Enum.sort(values)
    idx = max(0, round(length(sorted) * p / 100) - 1)
    Enum.at(sorted, idx)
  end

  @doc """
  Asserts the core overbooking invariant. No output — use `print_metrics/3` for display.

  Options: same as `print_metrics/3`.
  """
  def report(event_id, results, opts \\ []) do
    capacity = Keyword.fetch!(opts, :capacity)
    multinode = Keyword.get(opts, :multinode, false)
    metrics = compute_metrics(event_id, results)

    assert metrics.successes + metrics.failures == length(results),
           "not all tasks returned a result"

    assert metrics.successes <= capacity,
           "#{metrics.successes} succeeded but capacity is #{capacity}"

    assert metrics.db_count <= capacity,
           "DB shows #{metrics.db_count} tickets but capacity is #{capacity}"

    assert multinode || metrics.successes == metrics.db_count,
           "#{metrics.successes} successes and #{metrics.db_count} DB ticket count"

    metrics
  end

  @doc """
  Prints a metrics block. No assertions — pair with `report/3` in tests, call standalone in benchmarks.

  Options:
    - `:label`    — string prefix for the output block
    - `:capacity` — batch capacity
    - `:micros`   — wall time in microseconds (optional)
    - `:timings`  — list of per-request microseconds; enables p50/p99 lines
    - `:extra`    — keyword list of extra label→value lines to append
  """
  def print_metrics(event_id, results, opts \\ []) do
    capacity = Keyword.get(opts, :capacity, "?")
    label = Keyword.get(opts, :label, "perf")
    micros = Keyword.get(opts, :micros)
    timings = Keyword.get(opts, :timings, [])
    extra = Keyword.get(opts, :extra, [])

    %{successes: successes, failures: failures, db_count: db_count} =
      compute_metrics(event_id, results)

    time_line =
      if micros, do: "  wall time : #{Float.round(micros / 1000, 1)} ms\n", else: ""

    throughput_line =
      if micros && micros > 0 && successes > 0,
        do: "  throughput: #{Float.round(successes / (micros / 1_000_000), 1)} res/s\n",
        else: ""

    latency_lines =
      case timings do
        [] ->
          ""

        _ ->
          p50 = percentile(timings, 50)
          p99 = percentile(timings, 99)

          "  p50       : #{Float.round(p50 / 1000, 1)} ms\n  p99       : #{Float.round(p99 / 1000, 1)} ms\n"
      end

    extra_lines = Enum.map_join(extra, "", fn {k, v} -> "  #{k}: #{v}\n" end)

    IO.puts("""
    [#{label}] capacity=#{capacity}
      succeeded : #{successes}
      failed    : #{failures}
      db tickets: #{db_count}
    #{time_line}#{throughput_line}#{latency_lines}#{extra_lines}\
    """)
  end

  defp compute_metrics(event_id, results) do
    %{
      successes: Enum.count(results, &match?({:ok, _}, &1)),
      failures: Enum.count(results, &match?({:error, _}, &1)),
      db_count: count_active_tickets(event_id)
    }
  end

  # ---------------------------------------------------------------------------
  # Query helpers
  # ---------------------------------------------------------------------------

  @doc """
  Counts active (pending or paid) tickets for an event — the ground-truth
  overbooking check for the whole event.
  """
  def count_active_tickets(event_id) do
    import Ecto.Query

    Tiki.Repo.aggregate(
      from(t in Tiki.Orders.Ticket,
        join: o in Tiki.Orders.Order,
        on: t.order_id == o.id,
        where: o.event_id == ^event_id and o.status in [:pending, :paid]
      ),
      :count
    )
  end

  @doc """
  Counts active tickets restricted to the given ticket types.

  Accepts either a map of `%{key => %TicketType{}}` (as returned in the
  batches result) or a plain list of ticket type IDs.
  """
  def count_active_tickets_in(event_id, ticket_types) when is_map(ticket_types) do
    ids = ticket_types |> Map.values() |> Enum.map(& &1.id)
    count_active_tickets_in(event_id, ids)
  end

  def count_active_tickets_in(event_id, tt_ids) when is_list(tt_ids) do
    import Ecto.Query

    Tiki.Repo.aggregate(
      from(t in Tiki.Orders.Ticket,
        join: o in Tiki.Orders.Order,
        on: t.order_id == o.id,
        where:
          o.event_id == ^event_id and o.status in [:pending, :paid] and
            t.ticket_type_id in ^tt_ids
      ),
      :count
    )
  end

  @doc "Returns IDs of all pending orders for an event."
  def pending_order_ids(event_id) do
    import Ecto.Query

    Tiki.Repo.all(
      from o in Tiki.Orders.Order,
        where: o.event_id == ^event_id and o.status == :pending,
        select: o.id
    )
  end

  @doc "Returns the total capacity for a scenario"
  def scenario_capacity(%{batches: batches}) do
    batches |> Enum.map(&effective_capacity/1) |> Enum.sum()
  end

  defp effective_capacity(%{capacity: cap, batches: sub_batches}) do
    children_sum = sub_batches |> Enum.map(&effective_capacity/1) |> Enum.sum()
    min(cap * perf_scale(), children_sum)
  end

  defp effective_capacity(%{capacity: cap}), do: cap * perf_scale()

  @doc "Asserts per-batch capacity limits. No output."
  def verify_limits(event_id, batches) do
    for {ticket_type_lists, max_size, name} <- collect_checks(batches) do
      total =
        ticket_type_lists
        |> Enum.map(&count_active_tickets_in(event_id, &1))
        |> Enum.sum()

      assert total <= max_size, "#{name} overbooked: #{total} > #{max_size}"
    end
  end

  @doc "Prints per-batch capacity breakdown. No assertions."
  def print_limits(event_id, batches) do
    for {ticket_type_lists, max_size, name} <- collect_checks(batches) do
      total =
        ticket_type_lists
        |> Enum.map(&count_active_tickets_in(event_id, &1))
        |> Enum.sum()

      IO.puts("  #{name}: #{total} / #{max_size}")
    end
  end

  defp all_ticket_types(%{ticket_types: tts}), do: [tts]

  defp all_ticket_types(%{batches: sub_batches}) do
    sub_batches |> Map.values() |> Enum.flat_map(&all_ticket_types/1)
  end

  # Walk the tree and emit {ticket_type_lists, max_size, pool} tuples
  defp collect_checks(batches) do
    Enum.flat_map(batches, fn {name, entry} ->
      cond do
        entry.batches == %{} ->
          %{ticket_types: tts, batch: batch} = entry
          [{[tts], batch.max_size, name}]

        true ->
          %{batches: sub_batches, batch: parent_batch} = entry
          child_checks = collect_checks(sub_batches)
          pool_tts = sub_batches |> Map.values() |> Enum.flat_map(&all_ticket_types/1)
          pool_check = {pool_tts, parent_batch.max_size, name}
          child_checks ++ [pool_check]
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Private — spec execution
  # ---------------------------------------------------------------------------

  defp setup_from_spec(%{batches: batch_specs} = spec) do
    scale = perf_scale()
    load_factor = Map.get(spec, :load_factor, 2.0)

    {:ok, team} =
      Tiki.Teams.create_team(%{
        name: unique("perf-team"),
        contact_email: "#{unique("perf")}@test"
      })

    {:ok, event} =
      Tiki.Events.create_event(%{
        name: unique("perf-event"),
        name_sv: unique("perf-event"),
        description: "performance test event",
        description_sv: "performance test event",
        start_time: DateTime.utc_now() |> DateTime.shift_zone!("Europe/Stockholm"),
        location: "test",
        team_id: team.id,
        is_hidden: true
      })

    admin_id = ensure_perf_admin()
    scope = Tiki.Accounts.Scope.for(event: event.id, user: admin_id)

    batches = create_batches(scope, batch_specs, nil, scale)
    buyer_plan = build_buyer_plan(batches, batch_specs, load_factor, scale)

    %{
      event: event,
      batches: batches,
      buyer_plan: buyer_plan,
      cleanup: cleanup_fn(event.id, team.id, batches, delete_admin: true)
    }
  end

  # Inserts the shared perf admin user if not already present and (re-)grants
  # the admin permission in the mock permission service.
  defp ensure_perf_admin do
    now_usec = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:microsecond)
    now_sec = NaiveDateTime.truncate(now_usec, :second)

    Tiki.Repo.insert_all(
      Tiki.Accounts.User,
      [
        %{
          id: @perf_admin_id,
          email: "perf-admin@benchmark.local",
          locale: "en",
          confirmed_at: now_sec,
          inserted_at: now_usec,
          updated_at: now_usec
        }
      ],
      on_conflict: [set: [locale: "en", updated_at: now_usec]],
      conflict_target: :id
    )

    user = %Tiki.Accounts.User{id: @perf_admin_id}
    Tiki.Support.PermissionServiceMock.grant_permission(user, "admin")

    @perf_admin_id
  end

  # Recursively creates batches and their ticket types.
  # Returns %{"Batch Name" => %{batch: _, ticket_types: %{}, batches: %{}}}.
  defp create_batches(scope, specs, parent_batch_id, scale) do
    Map.new(specs, fn spec ->
      attrs =
        %{name: spec.name}
        |> maybe_put(:max_size, scale_val(Map.get(spec, :capacity), scale))
        |> maybe_put(:min_size, scale_val(Map.get(spec, :min_size), scale))
        |> maybe_put(:parent_batch_id, parent_batch_id)

      {:ok, batch} = Tiki.Tickets.create_ticket_batch(scope, attrs)

      ticket_types =
        Map.new(Map.get(spec, :ticket_types, []), fn tt_spec ->
          {:ok, tt} =
            Tiki.Tickets.create_ticket_type(scope, %{
              ticket_batch_id: batch.id,
              name: tt_spec.name,
              name_sv: tt_spec.name,
              description: "performance test ticket",
              description_sv: "performance test ticket",
              price: Map.get(tt_spec, :price, 0),
              purchasable: true,
              form_id: scope.event.default_form_id
            })

          {tt_spec.key, tt}
        end)

      children = create_batches(scope, Map.get(spec, :batches, []), batch.id, scale)

      {spec.name, %{batch: batch, ticket_types: ticket_types, batches: children}}
    end)
  end

  # Builds a shuffled list of individual purchase attempts.
  # Each entry: %{ticket_type: tt, batch: "name", key: :atom}
  # Buyer count per ticket type = batch_capacity × load_factor × (weight / total_weight)
  defp build_buyer_plan(batches_map, batch_specs, load_factor, scale) do
    batch_specs
    |> Enum.flat_map(fn spec ->
      %{ticket_types: tts, batches: children} = batches_map[spec.name]

      capacity = scale_val(Map.get(spec, :capacity, 0), scale) || 0
      tt_specs = Map.get(spec, :ticket_types, [])
      child_specs = Map.get(spec, :batches, [])

      own_entries =
        case tt_specs do
          [] ->
            []

          _ ->
            total_weight = tt_specs |> Enum.map(&Map.get(&1, :weight, 1)) |> Enum.sum()
            total_buyers = round(capacity * load_factor)

            Enum.flat_map(tt_specs, fn tt_spec ->
              weight = Map.get(tt_spec, :weight, 1)
              n = max(1, round(total_buyers * weight / total_weight))

              Enum.map(1..n, fn _ ->
                %{ticket_type: tts[tt_spec.key], batch: spec.name, key: tt_spec.key}
              end)
            end)
        end

      child_entries = build_buyer_plan(children, child_specs, load_factor, scale)
      own_entries ++ child_entries
    end)
    |> Enum.shuffle()
  end

  # Collects all batch IDs depth-first (children before parents) so the
  # cleanup DELETE respects FK ordering.
  defp collect_all_batch_ids(batches_map) do
    Enum.flat_map(batches_map, fn {_, %{batch: batch, batches: children}} ->
      collect_all_batch_ids(children) ++ [batch.id]
    end)
  end

  defp cleanup_fn(event_id, team_id, batches, opts) do
    batch_ids = collect_all_batch_ids(batches)
    delete_admin = Keyword.get(opts, :delete_admin, false)

    fn ->
      import Ecto.Query

      Tiki.Repo.delete_all(
        from t in Tiki.Orders.Ticket,
          join: o in Tiki.Orders.Order,
          on: t.order_id == o.id,
          where: o.event_id == ^event_id
      )

      Tiki.Repo.delete_all(
        from a in Tiki.Orders.AuditLog,
          join: o in Tiki.Orders.Order,
          on: a.order_id == o.id,
          where: o.event_id == ^event_id
      )

      Tiki.Repo.delete_all(from o in Tiki.Orders.Order, where: o.event_id == ^event_id)

      Tiki.Repo.delete_all(
        from tt in Tiki.Tickets.TicketType,
          where: tt.ticket_batch_id in ^batch_ids
      )

      Tiki.Repo.delete_all(
        from tb in Tiki.Tickets.TicketBatch,
          where: tb.id in ^batch_ids
      )

      Tiki.Repo.delete_all(from e in Tiki.Events.Event, where: e.id == ^event_id)
      Tiki.Repo.delete_all(from t in Tiki.Teams.Team, where: t.id == ^team_id)

      if delete_admin do
        Tiki.Repo.delete_all(from u in Tiki.Accounts.User, where: u.id == ^@perf_admin_id)
      end
    end
  end

  defp scale_val(nil, _scale), do: nil
  defp scale_val(n, scale), do: round(n * scale)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)

  defp unique(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"
end

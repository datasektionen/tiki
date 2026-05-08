defmodule Tiki.Performance.OrderHandler.ConcurrencyTest do
  @moduledoc """
  Correctness tests for ticket reservation under concurrent load.

  These tests use real DB transactions (no Ecto sandbox).

  The key invariant: total active tickets (pending + paid) must never exceed
  the batch capacity, regardless of how many concurrent reservation attempts
  are made.

  Scale is controlled via PERF_SCALE (multiplies scenario base capacity of 10):

      mix test --only performance              # PERF_SCALE=1  → capacity 10
      PERF_SCALE=50 mix test --only performance # PERF_SCALE=50 → capacity 500
  """

  use Tiki.PerformanceCase

  @moduletag :performance

  setup do
    %{event: event, batches: batches, cleanup: cleanup} =
      setup_event(spec: Scenarios.single_batch())

    %{batch: batch, ticket_types: %{general: tt}} = batches["General"]
    on_exit(cleanup)
    %{event: event, ticket_type: tt, capacity: batch.max_size}
  end

  test "no overbooking when buyers far exceed capacity", %{
    event: event,
    ticket_type: tt,
    capacity: capacity
  } do
    {micros, results, timings} = run_wave(event.id, tt, capacity * 3)

    report(event.id, results,
      label: "concurrency/overbooking",
      capacity: capacity,
      micros: micros,
      timings: timings
    )
  end

  test "all succeed when concurrent buyers exactly match capacity", %{
    event: event,
    ticket_type: tt,
    capacity: capacity
  } do
    {micros, results, timings} = run_wave(event.id, tt, capacity)

    successes = Enum.count(results, &match?({:ok, _}, &1))
    db_count = count_active_tickets(event.id)

    report(event.id, results,
      label: "concurrency/exact_match",
      capacity: capacity,
      micros: micros,
      timings: timings
    )

    assert successes == capacity, "expected all #{capacity} to succeed, got #{successes}"
    assert db_count == capacity

    assert {:error, _} = Orders.reserve_tickets(event.id, %{tt.id => 1}, nil)
    assert count_active_tickets(event.id) == capacity
  end

  test "single reservation baseline latency", %{event: event, ticket_type: tt, capacity: capacity} do
    run_capacity = min(capacity, 5)
    {micros, results, timings} = run_wave(event.id, tt, min(run_capacity, 5))

    report(event.id, results,
      label: "latency/baseline",
      capacity: run_capacity,
      micros: micros,
      timings: timings
    )

    assert percentile(timings, 99) < 5_000_000,
           "p99 latency exceeds 5 s — something is very wrong"
  end
end

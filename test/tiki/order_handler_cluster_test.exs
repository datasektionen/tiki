defmodule Tiki.OrderHandlerClusterTest do
  use Tiki.PerformanceCase

  @moduletag :cluster
  @moduletag :performance

  setup do
    scenario =
      Scenarios.single_batch()
      |> Map.put(:load_factor, 0.5)

    %{
      event: event,
      batches: batches,
      buyer_plan: plan,
      cleanup: cleanup
    } = setup_event(spec: scenario)

    %{batch: batch} = batches["General"]
    on_exit(cleanup)

    repo_config = Application.get_env(:tiki, Tiki.Repo, []) |> Keyword.put(:pool_size, 2)

    env = [
      tiki: [
        {Tiki.Repo, repo_config},
        {:metrics_port, 0}
      ]
    ]

    n_nodes = 3

    {:ok, cluster} = LocalCluster.start_link(n_nodes, environment: env)

    nodes =
      case LocalCluster.nodes(cluster) do
        {:ok, n} -> n
        n when is_list(n) -> n
      end

    # Configure the Ecto SQL sandbox to run in auto mode for these nodes
    Enum.each(nodes, fn node ->
      :rpc.call(node, Ecto.Adapters.SQL.Sandbox, :mode, [Tiki.Repo, :auto])
    end)

    %{event: event, buyer_plan: plan, capacity: batch.max_size, nodes: nodes}
  end

  test "concurrent reservations on multiple nodes lead to overselling when worker is local", %{
    nodes: nodes,
    event: event,
    buyer_plan: plan,
    capacity: capacity
  } do
    to_buy = Enum.frequencies_by(plan, & &1.ticket_type.id)

    Enum.map(nodes, fn node ->
      Task.async(fn ->
        :rpc.call(node, Tiki.Orders, :reserve_tickets, [event.id, to_buy, nil])
      end)
    end)
    |> Task.await_many()

    import Ecto.Query

    actual_reserved =
      Tiki.Repo.aggregate(
        from(t in Tiki.Orders.Ticket,
          join: o in Tiki.Orders.Order,
          on: t.order_id == o.id,
          where: o.event_id == ^event.id and o.status in [:pending, :paid]
        ),
        :count
      )

    assert actual_reserved <= capacity,
           "More tickets reserved than are available, reserved #{actual_reserved} with capacity #{capacity}"
  end
end

defmodule Tiki.OrdersTest do
  use Tiki.DataCase

  alias Tiki.Orders

  describe "order" do
    alias Tiki.Orders.Order

    import Tiki.OrdersFixtures

    @invalid_attrs %{"status" => "wierd"}
    @standard_preloads [:user, [tickets: :ticket_type], :stripe_checkout, :swish_checkout, :event]

    test "list_order/0 returns all order" do
      order = order_fixture()
      assert Orders.list_orders() == [order]
    end

    test "list_team_orders/1 returns all orders for a given team" do
      order = order_fixture() |> Tiki.Repo.preload([:event | @standard_preloads])

      assert Orders.list_team_orders(order.event.team_id) == [order]
    end

    test "list_team_orders/1 returns works for multiple orders" do
      event = Tiki.EventsFixtures.event_fixture()

      orders =
        Enum.map(1..10, fn _ ->
          user = Tiki.AccountsFixtures.user_fixture()

          {:ok, order} =
            Tiki.Orders.create_order(%{user_id: user.id, event_id: event.id, price: 100})

          order
        end)
        |> Enum.sort_by(& &1.inserted_at, :desc)
        |> Tiki.Repo.preload([:event | @standard_preloads])

      assert Orders.list_team_orders(event.team_id) == orders
    end

    test "list_team_orders/1 limits results" do
      event = Tiki.EventsFixtures.event_fixture()

      orders =
        Enum.map(1..3, fn _ ->
          user = Tiki.AccountsFixtures.user_fixture()

          {:ok, order} =
            Tiki.Orders.create_order(%{user_id: user.id, event_id: event.id, price: 100})

          order
        end)
        |> Enum.sort_by(& &1.inserted_at, :desc)
        |> Tiki.Repo.preload([:event | @standard_preloads])

      assert Orders.list_team_orders(event.team_id, limit: 3) == Enum.take(orders, 3)
    end

    test "list_team_orders/1 filters based on status" do
      event = Tiki.EventsFixtures.event_fixture()

      order_1 =
        order_fixture(%{status: :pending}, event: event)
        |> Tiki.Repo.preload([:event | @standard_preloads])

      order_2 =
        order_fixture(%{status: :paid}, event: event)
        |> Tiki.Repo.preload([:event | @standard_preloads])

      assert Orders.list_team_orders(event.team_id, status: [:pending]) == [order_1]
      assert Orders.list_team_orders(event.team_id, status: [:paid]) == [order_2]
    end

    test "list_orders_for_event/1 returns all orders for a given event" do
      event = Tiki.EventsFixtures.event_fixture()

      orders =
        Enum.map(1..5, fn _ ->
          status = Enum.random(Ecto.Enum.dump_values(Orders.Order, :status))

          order_fixture(%{status: status}, event: event)
          |> Tiki.Repo.preload(@standard_preloads)
        end)
        |> Enum.sort_by(& &1.inserted_at, :desc)
        |> Tiki.Repo.preload(@standard_preloads)

      assert Orders.list_orders_for_event(event.id) == orders
    end

    test "list_orders_for_event/1 filters based on status" do
      event = Tiki.EventsFixtures.event_fixture()

      :rand.seed(:exs64, {1, 1, 1})

      orders =
        Enum.map(1..5, fn _ ->
          status = Enum.random(Ecto.Enum.dump_values(Orders.Order, :status))

          order_fixture(%{status: status}, event: event)
          |> Tiki.Repo.preload(@standard_preloads)
        end)
        |> Enum.sort_by(& &1.inserted_at, :desc)
        |> Tiki.Repo.preload(@standard_preloads)

      assert Orders.list_orders_for_event(event.id, status: [:paid]) == [Enum.at(orders, 2)]
    end

    test "list_tickets_for_event/1 returns all tickets for a given event" do
      event = Tiki.EventsFixtures.event_fixture()

      tickets =
        Enum.map(1..5, fn _ ->
          batch = Tiki.TicketsFixtures.ticket_batch_fixture(%{event_id: event.id})
          ticket_type = Tiki.TicketsFixtures.ticket_type_fixture(%{batch_id: batch.id})
          order = Tiki.OrdersFixtures.order_fixture(%{event_id: event.id})

          ticket_fixture(%{order_id: order.id, ticket_type_id: ticket_type.id})
        end)
        |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})
        |> Repo.preload(order: [:user], ticket_type: [])

      assert Orders.list_tickets_for_event(event.id) == tickets
    end

    test "list_tickets_for_event/1 limits the number of tickets returned" do
      event = Tiki.EventsFixtures.event_fixture()

      tickets =
        Enum.map(1..5, fn _ ->
          batch = Tiki.TicketsFixtures.ticket_batch_fixture(%{event_id: event.id})
          ticket_type = Tiki.TicketsFixtures.ticket_type_fixture(%{batch_id: batch.id})
          order = Tiki.OrdersFixtures.order_fixture(%{event_id: event.id})

          ticket_fixture(%{order_id: order.id, ticket_type_id: ticket_type.id})
        end)
        |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})
        |> Repo.preload(order: [:user], ticket_type: [])

      assert Orders.list_tickets_for_event(event.id, limit: 3) == Enum.take(tickets, 3)
    end

    test "list_orders_for_user/1 returns all orders for a user" do
      user = Tiki.AccountsFixtures.user_fixture()

      order =
        order_fixture(%{user_id: user.id})
        |> Tiki.Repo.preload([:event | @standard_preloads])

      assert Orders.list_orders_for_user(user.id) == [order]
    end

    test "get_order!/1 returns the order with given id" do
      order = order_fixture() |> Tiki.Repo.preload(@standard_preloads)
      assert Orders.get_order!(order.id) == order
    end

    test "create_order/1 with valid data creates a order" do
      event = Tiki.EventsFixtures.event_fixture()

      valid_attrs = %{event_id: event.id, price: 100}

      assert {:ok, %Order{} = _order} = Orders.create_order(valid_attrs)
    end

    test "create_order/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Orders.create_order(@invalid_attrs)
    end

    test "update_order/2 with valid data updates the order" do
      order = order_fixture()
      update_attrs = %{}

      assert {:ok, %Order{} = _order} = Orders.update_order(order, update_attrs)
    end

    test "update_order/2 with invalid data returns error changeset" do
      order = Tiki.Repo.preload(order_fixture(), @standard_preloads)

      assert {:error, %Ecto.Changeset{}} = Orders.update_order(order, @invalid_attrs)

      assert order ==
               Orders.get_order!(order.id)
    end

    test "delete_order/1 deletes the order" do
      order = order_fixture()
      assert {:ok, %Order{}} = Orders.delete_order(order)
      assert_raise Ecto.NoResultsError, fn -> Orders.get_order!(order.id) end
    end

    test "change_order/1 returns a order changeset" do
      order = order_fixture()
      assert %Ecto.Changeset{} = Orders.change_order(order)
    end
  end

  describe "ticket" do
    import Tiki.OrdersFixtures

    test "list_ticket/0 returns all ticket" do
      ticket = ticket_fixture()
      assert Orders.list_tickets() == [ticket]
    end

    test "get_ticket!/1 returns the ticket with given id" do
      ticket =
        ticket_fixture()
        |> Tiki.Repo.preload([:ticket_type, order: [:user], form_response: [:question_responses]])

      assert Orders.get_ticket!(ticket.id) == ticket
    end
  end

  describe "order reservation" do
    import Tiki.OrdersFixtures
    import Tiki.TicketsFixtures

    alias Tiki.Orders.Order

    test "reserve_tickets/3" do
      ticket_type = ticket_type_fixture() |> Tiki.Repo.preload(ticket_batch: [event: []])

      to_purchase = Map.put(%{}, ticket_type.id, 2)
      cost = ticket_type.price * 2

      Orders.subscribe(ticket_type.ticket_batch.event.id)

      result = Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert {:ok, %Order{status: :pending, price: ^cost, id: id}} = result

      Orders.subscribe_to_order(id)

      {:ok, order} = result

      assert to_purchase ==
               Enum.group_by(order.tickets, & &1.ticket_type.id)
               |> Enum.into(%{}, fn {tt, tickets} -> {tt, length(tickets)} end)

      assert Enum.all?(order.tickets, fn %{order_id: order_id} -> order_id == order.id end)
      assert cost == Enum.map(order.tickets, & &1.price) |> Enum.sum()

      assert_receive {:tickets_updated, _}
    end

    test "reserve_tickets/3 works with events with release and expire times" do
      ticket_type =
        ticket_type_fixture(
          release_time: DateTime.utc_now() |> DateTime.add(-60, :second),
          expire_time: DateTime.utc_now() |> DateTime.add(60, :second)
        )
        |> Tiki.Repo.preload(ticket_batch: [event: []])

      to_purchase = Map.put(%{}, ticket_type.id, 2)
      cost = ticket_type.price * 2

      Orders.subscribe(ticket_type.ticket_batch.event.id)

      result = Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert {:ok, %Order{status: :pending, price: ^cost, id: id}} = result

      Orders.subscribe_to_order(id)

      {:ok, order} = result

      assert to_purchase ==
               Enum.group_by(order.tickets, & &1.ticket_type.id)
               |> Enum.into(%{}, fn {tt, tickets} -> {tt, length(tickets)} end)

      assert Enum.all?(order.tickets, fn %{order_id: order_id} -> order_id == order.id end)
      assert cost == Enum.map(order.tickets, & &1.price) |> Enum.sum()

      assert_receive {:tickets_updated, _}
    end

    test "reserve_tickets/3 fails if reserving no tickets" do
      ticket_type = ticket_type_fixture() |> Tiki.Repo.preload(ticket_batch: [event: []])
      to_purchase = Map.put(%{}, ticket_type.id, 0)

      assert {:error, msg} =
               Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert msg =~ "order must contain at least one ticket"
    end

    test "reserve_tickets/3 fails if reserving too many tickets of a single type" do
      ticket_type =
        ticket_type_fixture(purchase_limit: 2) |> Tiki.Repo.preload(ticket_batch: [event: []])

      to_purchase = Map.put(%{}, ticket_type.id, 3)

      assert {:error, msg} =
               Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert msg =~ "too many tickets requested"
    end

    test "reserve_tickets/3 fails if reserving too many tickets for an event" do
      event = Tiki.EventsFixtures.event_fixture(max_order_size: 2)
      batch = ticket_batch_fixture(%{event_id: event.id})

      ticket_type =
        ticket_type_fixture(purchase_limit: 10, ticket_batch_id: batch.id)
        |> Tiki.Repo.preload(ticket_batch: [event: []])

      to_purchase = Map.put(%{}, ticket_type.id, 3)

      assert {:error, msg} =
               Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert msg =~ "too many tickets requested"
    end

    test "reserve_tickets/3 fails if reserving tickets that are not purchasable" do
      ticket_type =
        ticket_type_fixture(purchasable: false) |> Tiki.Repo.preload(ticket_batch: [event: []])

      to_purchase = Map.put(%{}, ticket_type.id, 3)

      assert {:error, msg} =
               Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert msg =~ "not all ticket types are purchasable"
    end

    test "reserve_tickets/3 fails if reserving too many tickets" do
      ticket_type = ticket_type_fixture() |> Tiki.Repo.preload(ticket_batch: [event: []])
      to_purchase = Map.put(%{}, ticket_type.id, 43)

      assert {:error, msg} =
               Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert msg =~ "not enough tickets available"
    end

    test "reserve_tickets/3 fails if reserving tickets to wrong event" do
      ticket_type = ticket_type_fixture() |> Tiki.Repo.preload(ticket_batch: [event: []])
      invalid_ticket_type = ticket_type_fixture()
      to_purchase = Map.put(%{}, ticket_type.id, 2) |> Map.put(invalid_ticket_type.id, 1)

      assert {:error, msg} =
               Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert msg =~ "not enough tickets"
    end

    test "reserve_tickets/3 fails if reserving tickets that are not released yet" do
      ticket_type =
        ticket_type_fixture(release_time: DateTime.utc_now() |> DateTime.add(60, :second))
        |> Tiki.Repo.preload(ticket_batch: [event: []])

      to_purchase = Map.put(%{}, ticket_type.id, 1)

      assert {:error, msg} =
               Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert msg =~ "not all ticket types are purchasable"
    end

    test "reserve_tickets/3 fails if reserving tickets that have expired" do
      ticket_type =
        ticket_type_fixture(expire_time: DateTime.utc_now() |> DateTime.add(-60, :second))
        |> Tiki.Repo.preload(ticket_batch: [event: []])

      to_purchase = Map.put(%{}, ticket_type.id, 1)

      assert {:error, msg} =
               Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert msg =~ "not all ticket types are purchasable"
    end

    test "maybe_cancel_order/1 cancels a pending order" do
      order = order_fixture(%{status: "pending"})

      assert {:ok, order} = Orders.maybe_cancel_order(order.id)
      assert order.status == :cancelled
      assert %Orders.Order{status: :cancelled, tickets: []} = Orders.get_order!(order.id)
    end

    test "maybe_cancel_order/1 does not modify paid orders" do
      order = order_fixture(%{status: "paid"})
      ticket = ticket_fixture(%{order_id: order.id}) |> Repo.preload(:ticket_type)

      assert {:error, msg} = Orders.maybe_cancel_order(order.id)
      assert msg =~ "order is not pending"

      assert %Orders.Order{status: :paid, tickets: [^ticket]} = Orders.get_order!(order.id)
    end

    test "maybe_cancel_order/1 does not modify cancelled orders" do
      order = order_fixture(%{status: "cancelled"}) |> Repo.preload(@standard_preloads)

      assert {:error, msg} = Orders.maybe_cancel_order(order.id)
      assert msg =~ "order is not pending"

      assert Orders.get_order!(order.id) == order
    end

    test "maybe_cancel_order/1 returns an error if the order does not exist" do
      assert {:error, msg} = Orders.maybe_cancel_order(Ecto.UUID.generate())
      assert msg =~ "order not found, nothing to cancel"
    end
  end
end

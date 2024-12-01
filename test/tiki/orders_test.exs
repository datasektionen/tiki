defmodule Tiki.OrdersTest do
  use Tiki.DataCase

  alias Tiki.Orders

  describe "order" do
    alias Tiki.Orders.Order

    import Tiki.OrdersFixtures

    @invalid_attrs %{"status" => "wierd"}
    @standard_preloads [:user, [tickets: :ticket_type], :stripe_checkout, :swish_checkout]

    test "list_order/0 returns all order" do
      order = order_fixture()
      assert Orders.list_orders() == [order]
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

    test "reserve_tickets/3 fails if reserving too many tickets" do
      ticket_type = ticket_type_fixture() |> Tiki.Repo.preload(ticket_batch: [event: []])
      to_purchase = Map.put(%{}, ticket_type.id, 43)

      assert {:error, msg} =
               Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert msg =~ "not enough tickets"
    end

    test "reserve_tickets/3 fails if reserving tickets to wrong event" do
      ticket_type = ticket_type_fixture() |> Tiki.Repo.preload(ticket_batch: [event: []])
      invalid_ticket_type = ticket_type_fixture()
      to_purchase = Map.put(%{}, ticket_type.id, 2) |> Map.put(invalid_ticket_type.id, 1)

      assert {:error, msg} =
               Orders.reserve_tickets(ticket_type.ticket_batch.event.id, to_purchase)

      assert msg =~ "not enough tickets"
    end

    test "maybe_cancel_reservation/1" do
      # TODO
    end
  end
end

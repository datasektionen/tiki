defmodule Tiki.OrdersTest do
  use Tiki.DataCase

  alias Tiki.Tickets.TicketBatch
  alias Tiki.Orders

  describe "order" do
    alias Tiki.Orders.Order

    import Tiki.OrdersFixtures
    import Tiki.EventsFixtures

    @invalid_attrs %{"status" => "wierd"}

    test "list_order/0 returns all order" do
      order = order_fixture()
      assert Orders.list_orders() == [order]
    end

    test "get_order!/1 returns the order with given id" do
      order = order_fixture()
      assert Orders.get_order!(order.id) == order
    end

    test "create_order/1 with valid data creates a order" do
      valid_attrs = %{}

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
      order = order_fixture()
      assert {:error, %Ecto.Changeset{}} = Orders.update_order(order, @invalid_attrs)
      assert order == Orders.get_order!(order.id)
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
    alias Tiki.Orders.Ticket

    import Tiki.OrdersFixtures

    @invalid_attrs %{}

    test "list_ticket/0 returns all ticket" do
      ticket = ticket_fixture()
      assert Orders.list_tickets() == [ticket]
    end

    test "get_ticket!/1 returns the ticket with given id" do
      ticket = ticket_fixture()
      assert Orders.get_ticket!(ticket.id) == ticket
    end

    test "create_ticket/1 with valid data creates a ticket" do
      valid_attrs = %{}

      assert {:ok, %Ticket{} = _ticket} = Orders.create_ticket(valid_attrs)
    end

    # test "create_ticket/1 with invalid data returns error changeset" do
    #   assert {:error, %Ecto.Changeset{}} = Orders.create_ticket(@invalid_attrs)
    # end

    test "update_ticket/2 with valid data updates the ticket" do
      ticket = ticket_fixture()
      update_attrs = %{}

      assert {:ok, %Ticket{} = _ticket} = Orders.update_ticket(ticket, update_attrs)
    end

    # test "update_ticket/2 with invalid data returns error changeset" do
    #   ticket = ticket_fixture()
    #   assert {:error, %Ecto.Changeset{}} = Orders.update_ticket(ticket, @invalid_attrs)
    #   assert ticket == Orders.get_ticket!(ticket.id)
    # end

    test "delete_ticket/1 deletes the ticket" do
      ticket = ticket_fixture()
      assert {:ok, %Ticket{}} = Orders.delete_ticket(ticket)
      assert_raise Ecto.NoResultsError, fn -> Orders.get_ticket!(ticket.id) end
    end

    test "change_ticket/1 returns a ticket changeset" do
      ticket = ticket_fixture()
      assert %Ecto.Changeset{} = Orders.change_ticket(ticket)
    end
  end
end

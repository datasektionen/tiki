defmodule Tiki.OrdersTest do
  use Tiki.DataCase

  alias Tiki.Orders

  describe "order" do
    alias Tiki.Orders.Order

    import Tiki.OrdersFixtures

    @invalid_attrs %{"status" => "wierd"}

    test "list_order/0 returns all order" do
      order = order_fixture()
      assert Orders.list_orders() == [order]
    end

    test "get_order!/1 returns the order with given id" do
      order = order_fixture() |> Tiki.Repo.preload([:user, [tickets: :ticket_type]])
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
      order = order_fixture() |> Tiki.Repo.preload([:user, [tickets: :ticket_type]])
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
      ticket = ticket_fixture() |> Tiki.Repo.preload([:ticket_type, order: [:user]])
      assert Orders.get_ticket!(ticket.id) == ticket
    end
  end
end

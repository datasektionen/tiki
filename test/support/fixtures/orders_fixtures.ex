defmodule Tiki.OrdersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Tiki.Orders` context.
  """

  @doc """
  Generate a order.
  """
  def order_fixture(attrs \\ %{}, opts \\ []) do
    user = Tiki.AccountsFixtures.user_fixture()

    event =
      case Keyword.get(opts, :event) do
        nil -> Tiki.EventsFixtures.event_fixture()
        event -> event
      end

    {:ok, order} =
      attrs
      |> Enum.into(%{user_id: user.id, event_id: event.id, price: 100})
      |> Tiki.Orders.create_order()

    order
  end

  @doc """
  Generate a ticket.
  """
  def ticket_fixture(attrs \\ %{}) do
    ticket_type = Tiki.TicketsFixtures.ticket_type_fixture()
    order = Tiki.OrdersFixtures.order_fixture()

    {:ok, ticket} =
      attrs
      |> Enum.into(%{
        ticket_type_id: ticket_type.id,
        price: order.price,
        order_id: order.id
      })
      |> Tiki.Orders.create_ticket()

    ticket
  end
end

defmodule Tiki.OrdersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Tiki.Orders` context.
  """

  @doc """
  Generate a order.
  """
  def order_fixture(attrs \\ %{}) do
    {:ok, order} =
      attrs
      |> Enum.into(%{

      })
      |> Tiki.Orders.create_order()

    order
  end

  @doc """
  Generate a ticket.
  """
  def ticket_fixture(attrs \\ %{}) do
    {:ok, ticket} =
      attrs
      |> Enum.into(%{

      })
      |> Tiki.Orders.create_ticket()

    ticket
  end
end

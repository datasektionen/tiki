defmodule Tiki.TicketsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Tiki.Tickets` context.
  """

  @doc """
  Generate a ticket_batch.
  """
  def ticket_batch_fixture(attrs \\ %{}) do
    {:ok, ticket_batch} =
      attrs
      |> Enum.into(%{
        max_size: 42,
        min_size: 42,
        name: "some name"
      })
      |> Tiki.Tickets.create_ticket_batch()

    ticket_batch
  end

  @doc """
  Generate a ticket_types.
  """
  def ticket_type_fixture(attrs \\ %{}) do
    {:ok, ticket_types} =
      attrs
      |> Enum.into(%{
        description: "some description",
        expire_time: ~U[2023-03-25 18:01:00Z],
        name: "some name",
        price: 42,
        purchasable: true,
        release_time: ~U[2023-03-25 18:01:00Z]
      })
      |> Tiki.Tickets.create_ticket_type()

    ticket_types
  end
end

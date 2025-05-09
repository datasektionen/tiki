defmodule Tiki.TicketsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Tiki.Tickets` context.
  """

  @doc """
  Generate a ticket_batch.
  """
  def ticket_batch_fixture(attrs \\ %{}) do
    event = Tiki.EventsFixtures.event_fixture()

    {:ok, ticket_batch} =
      attrs
      |> Enum.into(%{
        max_size: 42,
        min_size: 42,
        name: "some name",
        event_id: event.id
      })
      |> Tiki.Tickets.create_ticket_batch()

    ticket_batch
  end

  @doc """
  Generate a ticket_types.
  """
  def ticket_type_fixture(attrs \\ %{}) do
    batch = ticket_batch_fixture()
    form = Tiki.FormsFixtures.form_fixture()

    {:ok, ticket_types} =
      attrs
      |> Enum.into(%{
        description: "some description",
        name: "some name",
        price: 42,
        purchasable: true,
        ticket_batch_id: batch.id,
        form_id: form.id,
        purchase_limit: nil
      })
      |> Tiki.Tickets.create_ticket_type()

    ticket_types
  end
end

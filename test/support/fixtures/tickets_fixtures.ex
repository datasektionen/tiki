defmodule Tiki.TicketsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Tiki.Tickets` context.
  """

  @doc """
  Generate a ticket_batch.
  """
  def ticket_batch_fixture(attrs \\ %{}) do
    event = Map.get(attrs, :event, Tiki.EventsFixtures.event_fixture())

    user = Map.get(attrs, :user, Tiki.AccountsFixtures.admin_user_fixture())
    scope = Tiki.Accounts.Scope.for(event: event.id, user: user.id)

    {:ok, ticket_batch} =
      attrs
      |> Enum.into(%{
        max_size: 42,
        min_size: 42,
        name: "some name"
      })
      |> then(&Tiki.Tickets.create_ticket_batch(scope, &1))

    ticket_batch
  end

  @doc """
  Generate a ticket_type.
  """
  def ticket_type_fixture(attrs \\ %{}) do
    batch_id = Map.get(attrs, :ticket_batch_id, ticket_batch_fixture().id)
    form = Tiki.FormsFixtures.form_fixture()

    batch = Tiki.Tickets.get_ticket_batch!(batch_id)

    user = Map.get(attrs, :user, Tiki.AccountsFixtures.admin_user_fixture())
    scope = Tiki.Accounts.Scope.for(event: batch.event_id, user: user.id)

    {:ok, ticket_types} =
      attrs
      |> Enum.into(%{
        description: "some description",
        description_sv: "någon beskrivning",
        name: "some name",
        name_sv: "något namn",
        price: 42,
        purchasable: true,
        ticket_batch_id: batch_id,
        form_id: form.id,
        purchase_limit: nil
      })
      |> then(&Tiki.Tickets.create_ticket_type(scope, &1))

    ticket_types
  end
end

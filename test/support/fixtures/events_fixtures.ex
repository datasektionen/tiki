defmodule Tiki.EventsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Tiki.Events` context.
  """

  @doc """
  Generate a event.
  """
  def event_fixture(attrs \\ %{}) do
    team = Tiki.TeamsFixtures.team_fixture()

    {:ok, event} =
      attrs
      |> Enum.into(%{
        description: "some description",
        event_date: ~U[2023-03-25 16:55:00Z],
        name: "some name",
        team_id: team.id
      })
      |> Tiki.Events.create_event()

    event
  end

  @doc """
  Generate an example event, with batches and ticket types.
  """
  def example_event_fixture(attrs \\ %{}) do
    event = event_fixture(attrs)

    {:ok, external} =
      Tiki.Tickets.create_ticket_batch(%{event_id: event.id, name: "External", max_size: 5})

    {:ok, regular} =
      Tiki.Tickets.create_ticket_batch(%{event_id: event.id, name: "Biljetter", max_size: 20})

    {:ok, alumns} =
      Tiki.Tickets.create_ticket_batch(%{
        event_id: event.id,
        name: "Alumner",
        min_size: 7,
        parent_batch_id: regular.id
      })

    {:ok, students} =
      Tiki.Tickets.create_ticket_batch(%{
        event_id: event.id,
        name: "Studenter",
        parent_batch_id: regular.id
      })

    Tiki.Tickets.create_ticket_type(%{
      ticket_batch_id: external.id,
      name: "Styrelser",
      price: 600
    })

    Tiki.Tickets.create_ticket_type(%{
      ticket_batch_id: external.id,
      name: "Inbjudna",
      price: 600
    })

    Tiki.Tickets.create_ticket_type(%{
      ticket_batch_id: students.id,
      name: "Studentbiljett",
      price: 400
    })

    Tiki.Tickets.create_ticket_type(%{
      ticket_batch_id: alumns.id,
      name: "Alumnbiljett",
      price: 600
    })

    event
  end
end

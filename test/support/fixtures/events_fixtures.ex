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
        description_sv: "någon beskrivning",
        start_time: ~U[2023-03-25 16:55:00Z] |> DateTime.shift_zone!("Europe/Stockholm"),
        name: "some name",
        name_sv: "något namn",
        location: "some location",
        team_id: team.id,
        is_hidden: false
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
      name_sv: "Styrelser",
      description: "External ticket for board members",
      description_sv: "Extern biljett för styrelser",
      price: 600
    })

    Tiki.Tickets.create_ticket_type(%{
      ticket_batch_id: external.id,
      name: "Inbjudna",
      name_sv: "Inbjudna",
      description: "External ticket for invited guests",
      description_sv: "Extern biljett för inbjudna gäster",
      price: 600
    })

    Tiki.Tickets.create_ticket_type(%{
      ticket_batch_id: students.id,
      name: "Studentbiljett",
      name_sv: "Studentbiljett",
      description: "Student ticket",
      description_sv: "Biljett för studenter",
      price: 400
    })

    Tiki.Tickets.create_ticket_type(%{
      ticket_batch_id: alumns.id,
      name: "Alumnbiljett",
      name_sv: "Alumnbiljett",
      description: "Alumni ticket",
      description_sv: "Biljett för alumner",
      price: 600
    })

    event
  end
end

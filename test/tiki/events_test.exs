defmodule Tiki.EventsTest do
  use Tiki.DataCase

  alias Tiki.Events

  describe "events" do
    alias Tiki.Events.Event

    import Tiki.EventsFixtures

    @invalid_attrs %{description: nil, event_date: nil, name: nil}

    test "list_events/0 returns all events" do
      event = event_fixture()
      assert Events.list_events() == [event]
    end

    test "list_public_events/0 returns all public events" do
      public_event = event_fixture(%{is_hidden: false})
      _private_event = event_fixture(%{is_hidden: true})

      assert Events.list_public_events() == [public_event]
    end

    test "list_team_events/1 returns all events for a team" do
      team = Tiki.TeamsFixtures.team_fixture()
      event = event_fixture(%{team_id: team.id})
      assert Events.list_team_events(team.id) == [event]
    end

    test "get_event!/1 returns the event with given id" do
      event = event_fixture() |> Tiki.Repo.preload([:team])
      assert Events.get_event!(event.id) == event
    end

    test "get_event!/1 can preload tickt types" do
      event = event_fixture() |> Tiki.Repo.preload(ticket_batches: [:ticket_types], team: [])
      assert Events.get_event!(event.id, preload_ticket_types: true) == event
    end

    test "get_event_ticket_types/1 returns a list of ticket types for an event" do
      event = event_fixture()
      assert Events.get_event_ticket_types(event.id) == []

      ticket_types =
        Enum.flat_map(1..3, fn _ ->
          batch = Tiki.TicketsFixtures.ticket_batch_fixture(%{event_id: event.id})

          Enum.map(1..3, fn _ ->
            Tiki.TicketsFixtures.ticket_type_fixture(%{ticket_batch_id: batch.id})
          end)
        end)

      assert Events.get_event_ticket_types(event.id) |> Enum.sort() == ticket_types |> Enum.sort()
    end

    test "create_event/1 with valid data creates a event" do
      team = Tiki.TeamsFixtures.team_fixture()

      valid_attrs = %{
        description: "some description",
        event_date: ~U[2023-03-25 16:55:00Z],
        name: "some name",
        team_id: team.id
      }

      assert {:ok, %Event{} = event} = Events.create_event(valid_attrs)
      assert event.description == "some description"
      assert event.event_date == ~U[2023-03-25 16:55:00Z]
      assert event.name == "some name"

      # Assert that we have a default form

      assert event.default_form_id != nil

      form = Tiki.Forms.get_form!(event.default_form_id)

      assert form.event_id == event.id
      assert form.name =~ "Default form"
      assert form.description =~ "We need some information to organize our event"

      assert [
               %{name: "Name", required: true, type: :attendee_name},
               %{name: "Email", required: true, type: :email}
             ] = form.questions
    end

    test "create_event/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Events.create_event(@invalid_attrs)
    end

    test "update_event/2 with valid data updates the event" do
      event = event_fixture()

      update_attrs = %{
        description: "some updated description",
        event_date: ~U[2023-03-26 16:55:00Z],
        name: "some updated name"
      }

      assert {:ok, %Event{} = event} = Events.update_event(event, update_attrs)
      assert event.description == "some updated description"
      assert event.event_date == ~U[2023-03-26 16:55:00Z]
      assert event.name == "some updated name"
    end

    test "update_event/2 with invalid data returns error changeset" do
      event = event_fixture() |> Tiki.Repo.preload([:team])
      assert {:error, %Ecto.Changeset{}} = Events.update_event(event, @invalid_attrs)
      assert event == Events.get_event!(event.id)
    end

    test "delete_event/1 deletes the event" do
      event = event_fixture()
      assert {:ok, %Event{}} = Events.delete_event(event)
      assert_raise Ecto.NoResultsError, fn -> Events.get_event!(event.id) end
    end

    test "change_event/1 returns a event changeset" do
      event = event_fixture()
      assert %Ecto.Changeset{} = Events.change_event(event)
    end
  end
end

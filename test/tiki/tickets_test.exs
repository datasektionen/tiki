defmodule Tiki.TicketsTest do
  use Tiki.DataCase

  alias Tiki.Tickets

  describe "ticket_batch" do
    alias Tiki.Tickets.TicketBatch

    import Tiki.TicketsFixtures

    @invalid_attrs %{max_size: nil, min_size: nil, name: nil}

    test "list_ticket_batch/0 returns all ticket_batch" do
      ticket_batch = ticket_batch_fixture()
      assert Tickets.list_ticket_batches() == [ticket_batch]
    end

    test "get_ticket_batch!/1 returns the ticket_batch with given id" do
      ticket_batch = ticket_batch_fixture()
      assert Tickets.get_ticket_batch!(ticket_batch.id) == ticket_batch
    end

    test "create_ticket_batch/1 with valid data creates a ticket_batch" do
      event = Tiki.EventsFixtures.event_fixture()
      valid_attrs = %{max_size: 42, min_size: 42, name: "some name", event_id: event.id}

      assert {:ok, %TicketBatch{} = ticket_batch} = Tickets.create_ticket_batch(valid_attrs)
      assert ticket_batch.max_size == 42
      assert ticket_batch.min_size == 42
      assert ticket_batch.name == "some name"
    end

    test "create_ticket_batch/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Tickets.create_ticket_batch(@invalid_attrs)
    end

    test "update_ticket_batch/2 with valid data updates the ticket_batch" do
      ticket_batch = ticket_batch_fixture()
      update_attrs = %{max_size: 43, min_size: 43, name: "some updated name"}

      assert {:ok, %TicketBatch{} = ticket_batch} =
               Tickets.update_ticket_batch(ticket_batch, update_attrs)

      assert ticket_batch.max_size == 43
      assert ticket_batch.min_size == 43
      assert ticket_batch.name == "some updated name"
    end

    test "update_ticket_batch/2 with invalid data returns error changeset" do
      ticket_batch = ticket_batch_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Tickets.update_ticket_batch(ticket_batch, @invalid_attrs)

      assert ticket_batch == Tickets.get_ticket_batch!(ticket_batch.id)

      assert {:error, %Ecto.Changeset{}} =
               Tickets.update_ticket_batch(ticket_batch, %{:parent_batch_id => ticket_batch.id})
    end

    test "delete_ticket_batch/1 deletes the ticket_batch" do
      ticket_batch = ticket_batch_fixture()
      assert {:ok, %TicketBatch{}} = Tickets.delete_ticket_batch(ticket_batch)
      assert_raise Ecto.NoResultsError, fn -> Tickets.get_ticket_batch!(ticket_batch.id) end
    end

    test "change_ticket_batch/1 returns a ticket_batch changeset" do
      ticket_batch = ticket_batch_fixture()
      assert %Ecto.Changeset{} = Tickets.change_ticket_batch(ticket_batch)
    end
  end

  describe "ticket_types" do
    alias Tiki.Tickets.TicketType

    import Tiki.TicketsFixtures

    @invalid_attrs %{
      description: nil,
      expire_time: nil,
      name: nil,
      price: nil,
      purchasable: nil,
      release_time: nil
    }

    test "list_ticket_type/0 returns all ticket_types" do
      ticket_types = ticket_type_fixture()
      assert Tickets.list_ticket_types() == [ticket_types]
    end

    test "get_ticket_type!/1 returns the ticket_types with given id" do
      ticket_types = ticket_type_fixture() |> Repo.preload(:ticket_batch)
      assert Tickets.get_ticket_type!(ticket_types.id) == ticket_types
    end

    test "create_ticket_type/1 with valid data creates a ticket_types" do
      batch = ticket_batch_fixture()
      form = Tiki.FormsFixtures.form_fixture()

      valid_attrs = %{
        description: "some description",
        expire_time: ~U[2023-03-25 18:01:00Z],
        name: "some name",
        price: 42,
        purchasable: true,
        release_time: ~U[2023-03-25 18:01:00Z],
        ticket_batch_id: batch.id,
        form_id: form.id
      }

      assert {:ok, %TicketType{} = ticket_types} = Tickets.create_ticket_type(valid_attrs)
      assert ticket_types.description == "some description"
      assert ticket_types.expire_time == ~U[2023-03-25 18:01:00Z]
      assert ticket_types.name == "some name"
      assert ticket_types.price == 42
      assert ticket_types.purchasable == true
      assert ticket_types.release_time == ~U[2023-03-25 18:01:00Z]
    end

    test "create_ticket_type/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Tickets.create_ticket_type(@invalid_attrs)
    end

    test "update_ticket_type/2 with valid data updates the ticket_types" do
      ticket_types = ticket_type_fixture()

      update_attrs = %{
        description: "some updated description",
        expire_time: ~U[2023-03-26 18:01:00Z],
        name: "some updated name",
        price: 43,
        purchasable: false,
        release_time: ~U[2023-03-26 18:01:00Z]
      }

      assert {:ok, %TicketType{} = ticket_types} =
               Tickets.update_ticket_type(ticket_types, update_attrs)

      assert ticket_types.description == "some updated description"
      assert ticket_types.expire_time == ~U[2023-03-26 18:01:00Z]
      assert ticket_types.name == "some updated name"
      assert ticket_types.price == 43
      assert ticket_types.purchasable == false
      assert ticket_types.release_time == ~U[2023-03-26 18:01:00Z]
    end

    test "update_ticket_type/2 with invalid data returns error changeset" do
      ticket_types = ticket_type_fixture() |> Repo.preload(:ticket_batch)

      assert {:error, %Ecto.Changeset{}} =
               Tickets.update_ticket_type(ticket_types, @invalid_attrs)

      assert ticket_types == Tickets.get_ticket_type!(ticket_types.id)
    end

    test "delete_ticket_type/1 deletes the ticket_types" do
      ticket_types = ticket_type_fixture()
      assert {:ok, %TicketType{}} = Tickets.delete_ticket_type(ticket_types)
      assert_raise Ecto.NoResultsError, fn -> Tickets.get_ticket_type!(ticket_types.id) end
    end

    test "change_ticket_type/1 returns a ticket_types changeset" do
      ticket_types = ticket_type_fixture()
      assert %Ecto.Changeset{} = Tickets.change_ticket_type(ticket_types)
    end
  end
end

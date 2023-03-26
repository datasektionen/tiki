defmodule Tiki.TicketsTest do
  use Tiki.DataCase

  alias Tiki.Tickets

  describe "ticket_batch" do
    alias Tiki.Tickets.TicketBatch

    import Tiki.TicketsFixtures

    @invalid_attrs %{max_size: nil, min_size: nil, name: nil}

    test "list_ticket_batch/0 returns all ticket_batch" do
      ticket_batch = ticket_batch_fixture()
      assert Tickets.list_ticket_batch() == [ticket_batch]
    end

    test "get_ticket_batch!/1 returns the ticket_batch with given id" do
      ticket_batch = ticket_batch_fixture()
      assert Tickets.get_ticket_batch!(ticket_batch.id) == ticket_batch
    end

    test "create_ticket_batch/1 with valid data creates a ticket_batch" do
      valid_attrs = %{max_size: 42, min_size: 42, name: "some name"}

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

  describe "ticket_type" do
    alias Tiki.Tickets.TicketType

    import Tiki.TicketsFixtures

    @invalid_attrs %{description: nil, expire_time: nil, name: nil, price: nil, purchasable: nil, release_time: nil}

    test "list_ticket_type/0 returns all ticket_type" do
      ticket_type = ticket_type_fixture()
      assert Tickets.list_ticket_type() == [ticket_type]
    end

    test "get_ticket_type!/1 returns the ticket_type with given id" do
      ticket_type = ticket_type_fixture()
      assert Tickets.get_ticket_type!(ticket_type.id) == ticket_type
    end

    test "create_ticket_type/1 with valid data creates a ticket_type" do
      valid_attrs = %{description: "some description", expire_time: ~U[2023-03-25 18:01:00Z], name: "some name", price: 42, purchasable: true, release_time: ~U[2023-03-25 18:01:00Z]}

      assert {:ok, %TicketType{} = ticket_type} = Tickets.create_ticket_type(valid_attrs)
      assert ticket_type.description == "some description"
      assert ticket_type.expire_time == ~U[2023-03-25 18:01:00Z]
      assert ticket_type.name == "some name"
      assert ticket_type.price == 42
      assert ticket_type.purchasable == true
      assert ticket_type.release_time == ~U[2023-03-25 18:01:00Z]
    end

    test "create_ticket_type/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Tickets.create_ticket_type(@invalid_attrs)
    end

    test "update_ticket_type/2 with valid data updates the ticket_type" do
      ticket_type = ticket_type_fixture()
      update_attrs = %{description: "some updated description", expire_time: ~U[2023-03-26 18:01:00Z], name: "some updated name", price: 43, purchasable: false, release_time: ~U[2023-03-26 18:01:00Z]}

      assert {:ok, %TicketType{} = ticket_type} = Tickets.update_ticket_type(ticket_type, update_attrs)
      assert ticket_type.description == "some updated description"
      assert ticket_type.expire_time == ~U[2023-03-26 18:01:00Z]
      assert ticket_type.name == "some updated name"
      assert ticket_type.price == 43
      assert ticket_type.purchasable == false
      assert ticket_type.release_time == ~U[2023-03-26 18:01:00Z]
    end

    test "update_ticket_type/2 with invalid data returns error changeset" do
      ticket_type = ticket_type_fixture()
      assert {:error, %Ecto.Changeset{}} = Tickets.update_ticket_type(ticket_type, @invalid_attrs)
      assert ticket_type == Tickets.get_ticket_type!(ticket_type.id)
    end

    test "delete_ticket_type/1 deletes the ticket_type" do
      ticket_type = ticket_type_fixture()
      assert {:ok, %TicketType{}} = Tickets.delete_ticket_type(ticket_type)
      assert_raise Ecto.NoResultsError, fn -> Tickets.get_ticket_type!(ticket_type.id) end
    end

    test "change_ticket_type/1 returns a ticket_type changeset" do
      ticket_type = ticket_type_fixture()
      assert %Ecto.Changeset{} = Tickets.change_ticket_type(ticket_type)
    end
  end
end

defmodule Tiki.Tickets do
  @moduledoc """
  The Tickets context.
  """

  import Ecto.Query, warn: false
  alias Tiki.Repo

  alias Tiki.Tickets.TicketBatch

  @doc """
  Returns the list of ticket_batch.

  ## Examples

      iex> list_ticket_batch()
      [%TicketBatch{}, ...]

  """
  def list_ticket_batch do
    Repo.all(TicketBatch)
  end

  @doc """
  Gets a single ticket_batch.

  Raises `Ecto.NoResultsError` if the Ticket batch does not exist.

  ## Examples

      iex> get_ticket_batch!(123)
      %TicketBatch{}

      iex> get_ticket_batch!(456)
      ** (Ecto.NoResultsError)

  """
  def get_ticket_batch!(id), do: Repo.get!(TicketBatch, id)

  @doc """
  Creates a ticket_batch.

  ## Examples

      iex> create_ticket_batch(%{field: value})
      {:ok, %TicketBatch{}}

      iex> create_ticket_batch(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_ticket_batch(attrs \\ %{}) do
    %TicketBatch{}
    |> TicketBatch.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a ticket_batch.

  ## Examples

      iex> update_ticket_batch(ticket_batch, %{field: new_value})
      {:ok, %TicketBatch{}}

      iex> update_ticket_batch(ticket_batch, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_ticket_batch(%TicketBatch{} = ticket_batch, attrs) do
    ticket_batch
    |> TicketBatch.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ticket_batch.

  ## Examples

      iex> delete_ticket_batch(ticket_batch)
      {:ok, %TicketBatch{}}

      iex> delete_ticket_batch(ticket_batch)
      {:error, %Ecto.Changeset{}}

  """
  def delete_ticket_batch(%TicketBatch{} = ticket_batch) do
    Repo.delete(ticket_batch)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking ticket_batch changes.

  ## Examples

      iex> change_ticket_batch(ticket_batch)
      %Ecto.Changeset{data: %TicketBatch{}}

  """
  def change_ticket_batch(%TicketBatch{} = ticket_batch, attrs \\ %{}) do
    TicketBatch.changeset(ticket_batch, attrs)
  end

  alias Tiki.Tickets.TicketType

  @doc """
  Returns the list of ticket_type.

  ## Examples

      iex> list_ticket_type()
      [%TicketType{}, ...]

  """
  def list_ticket_type do
    Repo.all(TicketType)
  end

  @doc """
  Gets a single ticket_type.

  Raises `Ecto.NoResultsError` if the Ticket type does not exist.

  ## Examples

      iex> get_ticket_type!(123)
      %TicketType{}

      iex> get_ticket_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_ticket_type!(id), do: Repo.get!(TicketType, id)

  @doc """
  Creates a ticket_type.

  ## Examples

      iex> create_ticket_type(%{field: value})
      {:ok, %TicketType{}}

      iex> create_ticket_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_ticket_type(attrs \\ %{}) do
    %TicketType{}
    |> TicketType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a ticket_type.

  ## Examples

      iex> update_ticket_type(ticket_type, %{field: new_value})
      {:ok, %TicketType{}}

      iex> update_ticket_type(ticket_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_ticket_type(%TicketType{} = ticket_type, attrs) do
    ticket_type
    |> TicketType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ticket_type.

  ## Examples

      iex> delete_ticket_type(ticket_type)
      {:ok, %TicketType{}}

      iex> delete_ticket_type(ticket_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_ticket_type(%TicketType{} = ticket_type) do
    Repo.delete(ticket_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking ticket_type changes.

  ## Examples

      iex> change_ticket_type(ticket_type)
      %Ecto.Changeset{data: %TicketType{}}

  """
  def change_ticket_type(%TicketType{} = ticket_type, attrs \\ %{}) do
    TicketType.changeset(ticket_type, attrs)
  end
end

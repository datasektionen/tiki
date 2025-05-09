defmodule Tiki.Events do
  @moduledoc """
  The Events context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Tiki.Repo

  alias Tiki.Events.Event

  @doc """
  Returns the list of events.

  ## Examples

      iex> list_events()
      [%Event{}, ...]

  """
  def list_events do
    Repo.all(Event)
  end

  @doc """
  Returns all publically visible events.
  """
  def list_public_events do
    Repo.all(from e in Event, where: e.is_hidden != true)
  end

  @doc """
  Returns the list of events, filtered by team.

  ## Examples

      iex> list_events()
      [%Event{}, ...]

  """
  def list_team_events(team_id) do
    Repo.all(from e in Event, where: e.team_id == ^team_id)
  end

  @doc """
  Gets a single event.

  Raises `Ecto.NoResultsError` if the Event does not exist.

  ## Examples

      iex> get_event!(123)
      %Event{}

      iex> get_event!(456)
      ** (Ecto.NoResultsError)

  """
  def get_event!(id, opts \\ []) do
    base_query =
      from e in Event,
        where: e.id == ^id,
        join: t in assoc(e, :team),
        preload: [team: t]

    base_query
    |> preload_ticket_types(Keyword.get(opts, :preload_ticket_types, false))
    |> Repo.one!()
  end

  defp preload_ticket_types(query, false), do: query

  defp preload_ticket_types(query, true) do
    from e in query,
      left_join: tb in assoc(e, :ticket_batches),
      left_join: tt in assoc(tb, :ticket_types),
      preload: [ticket_batches: {tb, ticket_types: tt}]
  end

  @doc """
  Gets statistics for an event. Returns a map with stats. Current statistics:

  * `:total_sales`, total sales in SEK
  * `:tickets_sold` total tickets sold
  """
  def get_event_stats!(id) do
    orders =
      Tiki.Orders.order_stats_query()
      |> where([o], o.event_id == ^id)

    query =
      from o in subquery(orders),
        select: %{
          total_sales: coalesce(sum(o.order_price), 0),
          tickets_sold: coalesce(sum(o.ticket_count), 0)
        }

    Repo.one!(query)
  end

  @doc """
  Creates an event.

  ## Examples

      iex> create_event(%{field: value})
      {:ok, %Event{}}

      iex> create_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_event(attrs \\ %{}) do
    multi =
      Multi.new()
      |> Multi.insert(:event, Event.changeset(%Event{}, attrs), returning: [:id])
      |> Multi.run(
        :default_form,
        fn _repo, %{event: event} ->
          Tiki.Forms.create_form(%{
            description: "We need some information to organize our event",
            name: "Default form",
            event_id: event.id,
            questions: [
              %{
                name: "Name",
                type: "attendee_name",
                required: true
              },
              %{
                name: "Email",
                type: "email",
                required: true
              }
            ]
          })
        end
      )
      |> Multi.update(:update_event_form, fn %{event: event, default_form: form} ->
        Event.changeset(event, %{default_form_id: form.id})
      end)
      |> Repo.transaction()

    case multi do
      {:ok, %{update_event_form: event}} ->
        {:ok, event}

      {:error, :event, changeset, _} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates a event.

  ## Examples

      iex> update_event(event, %{field: new_value})
      {:ok, %Event{}}

      iex> update_event(event, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_event(%Event{} = event, attrs) do
    event
    |> Event.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a event.

  ## Examples

      iex> delete_event(event)
      {:ok, %Event{}}

      iex> delete_event(event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_event(%Event{} = event) do
    Repo.delete(event)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking event changes.

  ## Examples

      iex> change_event(event)
      %Ecto.Changeset{data: %Event{}}

  """
  def change_event(%Event{} = event, attrs \\ %{}) do
    Event.changeset(event, attrs)
  end

  @doc """
  Returns a list of all ticket types for an event.

  ## Examples

      iex> get_event_ticket_types(123)
      [%TicketType{}, ...]

  """
  def get_event_ticket_types(event_id) do
    query =
      from e in Event,
        join: tb in assoc(e, :ticket_batches),
        join: tt in assoc(tb, :ticket_types),
        where: e.id == ^event_id,
        select: tt

    Repo.all(query)
  end
end

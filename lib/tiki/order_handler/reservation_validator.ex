defmodule Tiki.OrderHandler.ReservationValidator do
  @moduledoc false
  import Ecto.Query, warn: false
  require Logger

  alias Tiki.Repo
  alias Tiki.Tickets
  alias Tiki.Releases
  alias Tiki.Events
  alias Ecto.Multi

  # ============================================================================
  # Main Entry Point
  # ============================================================================

  @doc """
  Validates all reservation requirements for an order.

  Returns a map with validated data if all checks pass, or an error tuple
  with a user-friendly message.

  ## Examples

      iex> validate_all(event_id, %{tt_id => 2}, user_id)
      {:ok, %{
        ticket_types_map: %{...},
        event: %Event{},
        available_types: [...]
      }}

      iex> validate_all(event_id, %{tt_id => 0}, user_id)
      {:error, "order must contain at least one ticket"}
  """
  def validate_all(event_id, requested_tickets, user_id) do
    with {:ok, _} <- validate_positive_tickets(requested_tickets),
         {:ok, ticket_types_map} <- validate_and_fetch_ticket_types(requested_tickets),
         {:ok, _} <- validate_all_purchasable(ticket_types_map),
         {:ok, _} <- validate_release_access(ticket_types_map, user_id),
         {:ok, event} <- validate_event_exists(event_id),
         {:ok, _} <- validate_order_limits(ticket_types_map, event, requested_tickets),
         {:ok, available_types} <- validate_inventory(event_id, requested_tickets) do
      {:ok,
       %{
         ticket_types_map: ticket_types_map,
         event: event,
         available_types: available_types
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # ============================================================================
  # Individual Validations
  # ============================================================================

  @doc """
  Ensures at least 1 ticket is requested.
  """
  def validate_positive_tickets(requested_tickets) do
    case Map.values(requested_tickets) |> Enum.sum() do
      count when count > 0 ->
        {:ok, count}

      _ ->
        {:error, "order must contain at least one ticket"}
    end
  end

  @doc """
  Fetches ticket types from the database and validates they all exist.
  """
  def validate_and_fetch_ticket_types(requested_tickets) do
    tt_ids = Map.keys(requested_tickets)

    case tt_ids do
      [] ->
        {:error, "no ticket types requested"}

      _ ->
        existing =
          Repo.all(
            from tt in Tickets.TicketType,
              where: tt.id in ^tt_ids,
              select: {tt.id, tt}
          )
          |> Enum.into(%{})

        missing =
          MapSet.difference(
            MapSet.new(tt_ids),
            MapSet.new(Map.keys(existing))
          )

        case MapSet.size(missing) do
          0 ->
            {:ok, existing}

          _ ->
            missing_ids = Enum.join(missing, ", ")
            {:error, "some requested ticket types do not exist: #{missing_ids}"}
        end
    end
  end

  @doc """
  Checks that all requested ticket types are currently purchasable.

  Validates:
  - Ticket type is not disabled
  - Not past expiration time
  - Release time has arrived (if set)
  """
  def validate_all_purchasable(ticket_types_map) do
    non_purchasable =
      Enum.reject(ticket_types_map, fn {_, tt} ->
        purchaseable?(tt)
      end)

    case non_purchasable do
      [] ->
        {:ok, :purchasable}

      bad_types ->
        reasons =
          Enum.map(bad_types, fn {id, tt} ->
            cond do
              !tt.purchasable -> "#{id}: ticket type is disabled"
              is_expired?(tt) -> "#{id}: ticket sales have ended"
              not_yet_released?(tt) -> "#{id}: ticket sales have not yet opened"
            end
          end)

        error_msg = "not all tickets are purchasable: #{Enum.join(reasons, "; ")}"
        {:error, error_msg}
    end
  end

  @doc """
  Validates the user has access to all releases for the requested tickets.

  If any of the requested ticket types are part of an active release, the user
  must have an accepted signup for that release.
  """
  def validate_release_access(ticket_types_map, user_id) do
    tt_ids = Map.keys(ticket_types_map)

    # Find all active releases for these ticket types
    releases_query =
      from r in Releases.Release,
        join: tb in assoc(r, :ticket_batch),
        join: tt in assoc(tb, :ticket_types),
        where: tt.id in ^tt_ids,
        distinct: true,
        select: r

    releases =
      Repo.all(releases_query)
      |> Enum.filter(&Releases.is_active?/1)

    # If no active releases, access is granted
    case releases do
      [] ->
        {:ok, :no_releases}

      active_releases ->
        # For each active release, user must have an accepted signup
        all_authorized? =
          Enum.all?(active_releases, fn release ->
            has_accepted_signup?(release, user_id)
          end)

        if all_authorized? do
          {:ok, :authorized}
        else
          {:error, "tickets are part of an active release, which you are not accepted to"}
        end
    end
  end

  @doc """
  Ensures the event exists and is valid.
  """
  def validate_event_exists(event_id) do
    case Repo.one(from e in Events.Event, where: e.id == ^event_id) do
      %Events.Event{} = event ->
        {:ok, event}

      nil ->
        {:error, "event not found"}
    end
  end

  @doc """
  Validates the order respects purchase limits.

  Checks:
  - Each ticket type's individual purchase_limit
  - Event's max_order_size (total tickets in one order)
  """
  def validate_order_limits(ticket_types_map, event, requested_tickets) do
    total_requested = Map.values(requested_tickets) |> Enum.sum()

    # Check each ticket type's purchase limit
    per_type_valid =
      Enum.all?(requested_tickets, fn {tt_id, count} ->
        tt = ticket_types_map[tt_id]
        tt && tt.purchase_limit >= count
      end)

    # Check event's max order size
    total_valid = total_requested <= event.max_order_size

    case {per_type_valid, total_valid} do
      {true, true} ->
        {:ok, :within_limits}

      {false, _} ->
        {:error, "some tickets exceed their purchase limit"}

      {_, false} ->
        {:error, "order exceeds maximum event order size (limit: #{event.max_order_size})"}
    end
  end

  @doc """
  Validates sufficient inventory is available.

  Queries the number of available, pending, and purchased tickets,
  then verifies we have enough unallocated inventory for the requested amounts.
  """
  def validate_inventory(event_id, requested_tickets) do
    # Use the existing inventory calculation from Tickets context
    result =
      Multi.new()
      |> Tickets.get_available_ticket_types_multi(event_id)
      |> Repo.transaction()

    case result do
      {:ok, %{ticket_types_available: available}} ->
        # Verify we have enough of each requested type
        all_available =
          Enum.all?(requested_tickets, fn {tt_id, count} ->
            available_for_type =
              Enum.find(available, fn a ->
                a.ticket_type.id == tt_id
              end)

            available_for_type && available_for_type.available >= count
          end)

        if all_available do
          {:ok, available}
        else
          {:error, "not enough tickets available"}
        end

      {:error, _} ->
        {:error, "could not check inventory"}
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp purchaseable?(tt) do
    !is_expired?(tt) && !not_yet_released?(tt) && tt.purchasable
  end

  defp is_expired?(tt) do
    tt.expire_time && DateTime.compare(DateTime.utc_now(), tt.expire_time) == :gt
  end

  defp not_yet_released?(tt) do
    tt.release_time && DateTime.compare(DateTime.utc_now(), tt.release_time) == :lt
  end

  defp has_accepted_signup?(release, user_id) do
    Repo.exists?(
      from rs in Releases.Signup,
        where:
          rs.release_id == ^release.id and rs.user_id == ^user_id and
            rs.status == :accepted
    )
  end
end

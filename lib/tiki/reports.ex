defmodule Tiki.Reports do
  @moduledoc """
  Context for generating ticket sales reports.
  """

  import Ecto.Query, warn: false
  alias Tiki.Repo
  alias Tiki.Orders.{Order, AuditLog}

  @doc """
  Generate a ticket sales report with the given filters.

  ## Parameters
    * `:event_ids` - List of event IDs to include, or :all for all events
    * `:ticket_type_ids` - List of ticket type IDs to include, or :all for all types
    * `:start_date` - Date/DateTime to filter from (inclusive)
    * `:end_date` - Date/DateTime to filter to (inclusive)

  ## Returns
    A map containing:
      * `:summary` - List of maps with aggregated data per ticket type
      * `:details` - List of individual ticket transactions
      * `:grand_total` - Total revenue across all tickets
      * `:total_tickets` - Total number of tickets sold
  """
  def generate_report(opts) do
    event_ids = Keyword.get(opts, :event_ids, :all)
    ticket_type_ids = Keyword.get(opts, :ticket_type_ids, :all)
    start_date = Keyword.get(opts, :start_date)
    end_date = Keyword.get(opts, :end_date)
    include_details = Keyword.get(opts, :include_details, true)
    payment_type = Keyword.get(opts, :payment_type, "")

    # Query to get paid order audit logs with metadata containing historical prices
    query = paid_orders_query(event_ids, start_date, end_date, payment_type)

    audit_entries =
      Repo.all(query)

    # Extract tickets from metadata with historical prices
    tickets = extract_tickets_from_metadata(audit_entries, ticket_type_ids)

    # Generate summary and details
    summary = summarize_by_ticket_type(tickets)
    details = if include_details, do: build_detail_rows(audit_entries, tickets), else: []
    grand_total = Enum.sum(Enum.map(tickets, & &1.price))
    total_tickets = Enum.count(tickets)
    generated_at = DateTime.utc_now()

    %{
      summary: summary,
      details: details,
      grand_total: grand_total,
      total_tickets: total_tickets,
      generated_at: generated_at
    }
  end

  defp paid_orders_query(event_ids, start_date, end_date, payment_type) do
    # Query audit logs for "order.paid" events with preloaded order, event, and user data
    base_query =
      from al in AuditLog,
        where: al.event_type == "order.paid",
        join: o in Order,
        on: o.id == al.order_id,
        join: e in assoc(o, :event),
        left_join: u in assoc(o, :user),
        join: t in assoc(o, :tickets),
        join: tt in assoc(t, :ticket_type),
        preload: [order: {o, [event: e, user: u, tickets: {t, ticket_type: tt}]}]

    # Filter by event IDs (checking the order's event)
    query =
      if event_ids == :all do
        base_query
      else
        where(base_query, [al, o], o.event_id in ^event_ids)
      end

    # Filter by payment type (checking metadata for stripe_checkout or swish_checkout)
    query =
      case payment_type do
        "stripe" ->
          where(query, [al], fragment("? ->> ? IS NOT NULL", al.metadata, "stripe_checkout"))

        "swish" ->
          where(query, [al], fragment("? ->> ? IS NOT NULL", al.metadata, "swish_checkout"))

        _ ->
          query
      end

    # Filter by date range (inclusive, so end_date includes the whole day)
    query =
      if start_date do
        start_datetime = DateTime.new!(start_date, ~T[00:00:00], "Europe/Stockholm")
        where(query, [al], al.inserted_at >= ^start_datetime)
      else
        query
      end

    query =
      if end_date do
        # Add 1 day and use start of that day, so the entire end_date is included
        end_datetime = end_date |> Date.add(1) |> DateTime.new!(~T[00:00:00], "Europe/Stockholm")
        where(query, [al], al.inserted_at < ^end_datetime)
      else
        query
      end

    query |> order_by([al], desc: al.inserted_at)
  end

  defp extract_tickets_from_metadata(audit_entries, ticket_type_ids) do
    audit_entries
    |> Enum.flat_map(fn audit_log ->
      # Extract tickets array from metadata, with their historical prices

      metadata_tickets = audit_log.metadata["tickets"] || []

      metadata_tickets =
        Enum.map(metadata_tickets, fn ticket ->
          found_ticket =
            Enum.find(audit_log.order.tickets, fn find_ticket ->
              find_ticket.ticket_type_id == ticket["ticket_type"]["id"]
            end)

          Map.put(ticket, "ticket_type_name", found_ticket.ticket_type.name)
        end)

      Enum.map(metadata_tickets, fn ticket_data ->
        %{
          id: ticket_data["id"],
          price: ticket_data["price"],
          ticket_type_id: ticket_data["ticket_type"]["id"],
          ticket_type_name: ticket_data["ticket_type_name"],
          event_name: audit_log.order.event.name,
          event_id: audit_log.order.event_id,
          order_id: audit_log.order_id,
          paid_at: audit_log.inserted_at,
          order: audit_log.order
        }
      end)
    end)
    |> filter_by_ticket_types(ticket_type_ids)
  end

  defp filter_by_ticket_types(tickets, :all), do: tickets

  defp filter_by_ticket_types(tickets, ticket_type_ids) do
    Enum.filter(tickets, fn ticket ->
      ticket.ticket_type_id in ticket_type_ids
    end)
  end

  defp summarize_by_ticket_type(tickets) do
    tickets
    |> Enum.group_by(&{&1.event_id, &1.event_name})
    |> Enum.map(fn {{event_id, event_name}, event_tickets} ->
      event_summary =
        event_tickets
        |> Enum.group_by(& &1.ticket_type_id)
        |> Enum.map(fn {_tt_id, type_tickets} ->
          first_ticket = List.first(type_tickets)

          %{
            ticket_type_id: first_ticket.ticket_type_id,
            ticket_type_name: first_ticket.ticket_type_name,
            quantity: Enum.count(type_tickets),
            total_revenue: Enum.sum(Enum.map(type_tickets, & &1.price))
          }
        end)
        |> Enum.sort_by(& &1.ticket_type_name)

      event_total_revenue = Enum.sum(Enum.map(event_summary, & &1.total_revenue))
      event_total_quantity = Enum.sum(Enum.map(event_summary, & &1.quantity))

      %{
        event_id: event_id,
        event_name: event_name,
        items: event_summary,
        total_revenue: event_total_revenue,
        total_quantity: event_total_quantity
      }
    end)
    |> Enum.sort_by(& &1.event_name)
  end

  defp build_detail_rows(audit_entries, tickets) do
    # Create a map of ticket_id to audit entry for context lookup
    ticket_to_context =
      Enum.into(audit_entries, %{}, fn audit_log ->
        {audit_log.order_id, audit_log}
      end)

    tickets
    |> Enum.map(fn ticket ->
      audit_log = ticket_to_context[ticket.order_id]
      order = audit_log.order

      %{
        order_id: ticket.order_id,
        paid_at: ticket.paid_at,
        buyer_name: buyer_name(order),
        buyer_email: (order.user && order.user.email) || "Unknown",
        ticket_type_name: ticket.ticket_type_name,
        ticket_id: ticket.id,
        price: ticket.price,
        event_name: order.event.name,
        event_id: order.event_id
      }
    end)
    |> Enum.sort_by(fn row -> {row.event_name, row.paid_at} end)
  end

  defp buyer_name(order) do
    case order.user do
      %{first_name: first, last_name: last} when not is_nil(first) and not is_nil(last) ->
        "#{first} #{last}"

      %{email: email} ->
        email

      _ ->
        "Unknown"
    end
  end
end

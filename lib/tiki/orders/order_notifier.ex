defmodule Tiki.Orders.OrderNotifier do
  import Phoenix.Component
  import Swoosh.Email

  import TikiWeb.LiveHelpers, only: [time_to_string: 2]
  import Tiki.Mail.Layouts

  use Gettext, backend: TikiWeb.Gettext

  def deliver(order) do
    case render(%{order: order}) |> Tiki.Mail.Mjml.to_html() do
      {:ok, html} ->
        email =
          new()
          |> to(order.user.email)
          |> from({"Tiki", "noreply-tiki@datasektionen.se"})
          |> subject("Your order for #{order.event.name}")
          |> html_body(html)

        email =
          case ics(order) do
            nil ->
              email

            ics ->
              attachment(
                email,
                Swoosh.Attachment.new({:data, ics},
                  filename: "invite.ics",
                  content_type: "text/calendar",
                  type: :attachment
                )
              )
          end

        Tiki.Mail.Worker.new(%{email: Tiki.Mailer.to_map(email)})
        |> Oban.insert()
    end
  end

  defp get_summary(order) do
    order.tickets
    |> Enum.group_by(fn t -> t.ticket_type end)
    |> Enum.map(fn {tt, tickets} ->
      %{ticket_type: tt, count: Enum.count(tickets)}
    end)
  end

  defp render(assigns) do
    ~H"""
    <.default title={"Your order for #{@order.event.name}"}>
      <:section>
        <mj-column>
          <mj-text font-size="24px" font-weight="bold">Thank you for your order!</mj-text>
          <mj-text>
            We appreciate your purchase. Below are your order details. We look forward to seeing you at <a
              href={"#{TikiWeb.Endpoint.url()}/events/#{@order.event.id}"}
              style="text-decoration: underline; color: #18181b;"
              target="_blank"
            >{@order.event.name}</a>! Don't forget to fill
            in your attendance information.
          </mj-text>
        </mj-column>
      </:section>

      <:section>
        <mj-column>
          <.button href={"#{TikiWeb.Endpoint.url()}/orders/#{@order.id}"} align="left">
            View your tickets
          </.button>
        </mj-column>
      </:section>

      <:section>
        <mj-column width="100%">
          <.divider />
        </mj-column>
      </:section>

      <:section>
        <mj-column width="100%">
          <mj-text font-size="16px" font-weight="bold" padding-bottom="0">Reciept</mj-text>
          <mj-text>
            Buyer: {@order.user.full_name} <br /> Seller: Konglig datasektionen <br />
            Order Date: {time_to_string(@order.updated_at, format: :short)}, Order reference: {@order.id}
          </mj-text>

          <mj-table>
            <tr
              :for={%{ticket_type: tt, count: count} <- get_summary(@order)}
              style="border-spacing: 0; border-top:1px solid #e4e4e7;text-align:left;padding:0;"
            >
              <td style="padding: 5px 20px 5px 0; white-space: nowrap; font-weight: 700;">
                {tt.name}
              </td>
              <td style="padding: 0 10px 0 0; white-space: nowrap; text-align: right;">
                {"#{count} x #{tt.price} kr"}
              </td>
              <td style="padding: 0; text-align: right; white-space: nowrap;">
                {tt.price * count} kr
              </td>
            </tr>
            <tr style="border-spacing: 0; border-top:2px solid #e4e4e7;text-align:left;padding:0;">
              <td style="padding: 5px 20px 5px 0; white-space: nowrap;"></td>
              <td style="padding: 5px 10px 5px 0; white-space: nowrap; text-align: right;">
                {gettext("Total")}
              </td>
              <td style="padding: 0; text-align: right; white-space: nowrap;">
                {@order.price} kr
              </td>
            </tr>
          </mj-table>
        </mj-column>
      </:section>

      <:section>
        <mj-column width="100%">
          <mj-text font-size="16px" font-weight="bold" padding-bottom="0">
            Your tickets for {@order.event.name}
          </mj-text>
        </mj-column>
      </:section>

      <:section :for={ticket <- @order.tickets}>
        <mj-column width="100%">
          <.divider />
        </mj-column>
        <mj-column width="40%">
          <mj-text font-size="16px" font-weight="bold" padding-bottom="0">
            {ticket.ticket_type.name}
          </mj-text>
          <mj-text font-weight="bold">
            {time_to_string(ticket.ticket_type.start_time, format: :short)}
          </mj-text>
        </mj-column>

        <mj-column width="40%">
          <mj-image src={"#{TikiWeb.Endpoint.url()}/api/qr/#{ticket.id}"}></mj-image>
        </mj-column>
      </:section>
    </.default>
    """
  end

  def ics(order) do
    vevents =
      Enum.filter(order.tickets, fn t -> t.ticket_type.start_time && t.ticket_type.end_time end)
      |> Enum.group_by(fn t -> {t.ticket_type.start_time, t.ticket_type.end_time} end)
      |> Enum.map(fn {{start_time, end_time}, ts} ->
        """
        BEGIN:VEVENT
        UID:#{order.id}-#{hd(ts).id}
        DTSTAMP:#{format_date(DateTime.utc_now())}
        ORGANIZER;RSVP=FALSE;CN="Konglig Datasektionen":MAILTO:tiki@datasektionen.se
        URL:#{TikiWeb.Endpoint.url()}/events/#{order.event.id}
        DTSTART:#{format_date(start_time)}
        DTEND:#{format_date(end_time)}
        SUMMARY:#{order.event.name}
        DESCRIPTION:Event details: #{TikiWeb.Endpoint.url()}/events/#{order.event.id}\n\nYour Tickets: #{Enum.map(ts, fn t -> t.ticket_type.name end) |> Enum.join(", ")}
        LOCATION:#{order.event.location}
        END:VEVENT
        """
        |> String.trim_trailing()
      end)
      |> Enum.join("\n")

    case vevents do
      "" ->
        nil

      events ->
        """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:Konglig Datasektionen
        #{events}
        END:VCALENDAR
        """
        |> String.trim_trailing()
    end
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%Y%m%dT%H%M%SZ")
  end
end

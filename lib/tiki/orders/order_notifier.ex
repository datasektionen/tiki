defmodule Tiki.Orders.OrderNotifier do
  import Phoenix.Component
  import Swoosh.Email

  import TikiWeb.LiveHelpers, only: [time_to_string: 2]

  use Gettext, backend: TikiWeb.Gettext

  def deliver(order) do
    case render(%{order: order})
         |> Phoenix.HTML.Safe.to_iodata()
         |> to_string()
         |> Mjml.to_html() do
      {:ok, html} ->
        email =
          new()
          |> to(order.user.email)
          |> from({"Tiki", "noreply@tiki.se"})
          |> subject("Order Confirmation")
          |> html_body(html)
          |> Tiki.Mailer.to_map()

        Tiki.Mail.Worker.new(%{email: email})
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
    <mjml>
      <mj-head>
        <mj-preview>Order Confirmation</mj-preview>
        <mj-attributes>
          <mj-all font-family="'Helvetica Neue', Helvetica, Arial, sans-serif"></mj-all>
          <mj-text
            font-weight="400"
            font-size="14px"
            color="#18181b"
            line-height="24px"
            font-family="'Helvetica Neue', Helvetica, Arial, sans-serif"
          >
          </mj-text>
        </mj-attributes>
      </mj-head>
      <mj-body background-color="#EFEFEF" width="600px">
        <mj-wrapper padding-top="0" padding-bottom="0">
          <mj-section>
            <mj-column></mj-column>
          </mj-section>
        </mj-wrapper>

        <mj-section
          border-radius="15px 15px 0 0"
          padding-left="15px"
          padding-right="15px"
          background-color="#fff"
          padding-bottom="8px"
        >
          <mj-column>
            <mj-text font-size="24px" font-weight="bold">Thank you for your order!</mj-text>
            <mj-text>We appreciate your purchase. Below are your order details.</mj-text>
          </mj-column>
        </mj-section>

        <mj-section
          background-color="#ffffff"
          padding-left="15px"
          padding-right="15px"
          padding-top="0"
          padding-bottom="0"
        >
          <mj-column>
            <mj-button
              background-color="#18181b"
              color="#ffffff"
              border-radius="8px"
              font-size="14px"
              font-weight="bold"
              href={"http://localhost:4000/orders/#{@order.id}"}
              align="left"
            >
              View your tickets
            </mj-button>
          </mj-column>
        </mj-section>

        <mj-section
          background-color="#ffffff"
          padding-left="15px"
          padding-right="15px"
          padding-top="0"
          padding-bottom="0"
        >
          <mj-column width="100%">
            <mj-divider border-color="#e4e4e7" border-width="1px" />
          </mj-column>
        </mj-section>

        <mj-section
          background-color="#ffffff"
          padding-left="15px"
          padding-right="15px"
          padding-top="0"
          padding-bottom="0"
        >
          <mj-column width="100%">
            <mj-text font-size="16px" font-weight="bold" padding-bottom="0">Kvitto</mj-text>
            <mj-text>
              Köpare: {@order.user.full_name} <br /> Säljare: Konglig datasektionen <br />
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
        </mj-section>

        <%= for ticket <- @order.tickets do %>
          <mj-section
            background-color="#fff"
            padding-left="15px"
            padding-right="15px"
            padding-top="0"
            padding-bottom="0"
          >
            <mj-column width="100%">
              <mj-divider border-color="#e4e4e7" border-width="1px" />
            </mj-column>
          </mj-section>

          <mj-section
            background-color="#ffffff"
            padding-left="15px"
            padding-right="15px"
            padding-top="0"
            text-align="left"
          >
            <mj-column width="40%">
              <mj-text font-size="16px" font-weight="bold" padding-bottom="0">
                {ticket.ticket_type.name}
              </mj-text>
              <mj-text font-weight="bold">
                {time_to_string(ticket.ticket_type.start_time, format: :short)}
              </mj-text>
            </mj-column>

            <mj-column width="40%">
              <mj-image src={"http://localhost:4000/api/qr/#{ticket.id}"}></mj-image>
            </mj-column>
          </mj-section>
        <% end %>

        <mj-section
          background-color="#ffffff"
          padding-left="15px"
          padding-right="15px"
          padding-top="0"
          text-align="left"
          border-radius="0px 0px 15px 15px"
        >
          <mj-divider border-color="#e4e4e7" border-width="1px" />
        </mj-section>

        <mj-section>
          <mj-column>
            <mj-text font-size="14px">
              Tiki är en eventplattform utvecklad för och av Datasektionen på KTH. <br />
              tiki@datasektionen.se
            </mj-text>
          </mj-column>
        </mj-section>
      </mj-body>
    </mjml>
    """
  end
end

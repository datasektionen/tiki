defmodule Tiki.Orders.OrderNotifier do
  import Phoenix.Component
  import Swoosh.Email

  def deliver(order) do
    case render(%{})
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

  defp render(assigns) do
    ~H"""
    <mjml>
      <mj-head>
        <mj-preview>Order Confirmation</mj-preview>
      </mj-head>
      <mj-body>
        <mj-section>
          <mj-column>
            <mj-text font-size="20px" font-weight="bold">Thank you for your order!</mj-text>
            <mj-text>We appreciate your purchase. Below are your order details.</mj-text>
          </mj-column>
        </mj-section>

        <mj-section>
          <mj-column>
            <mj-text font-size="16px" font-weight="bold">Order Summary</mj-text>
            <mj-text>Order Number: #123456</mj-text>
            <mj-text>Order Date: 2024-02-09</mj-text>
          </mj-column>
        </mj-section>

        <mj-section>
          <mj-column>
            <mj-text font-size="16px" font-weight="bold">Items Ordered</mj-text>
            <mj-text>1x Product Name - $19.99</mj-text>
            <mj-text>2x Another Product - $39.98</mj-text>
          </mj-column>
        </mj-section>

        <mj-section>
          <mj-column>
            <mj-text font-size="16px" font-weight="bold">Total: $59.97</mj-text>
          </mj-column>
        </mj-section>

        <mj-section>
          <mj-column>
            <mj-text>If you have any questions, feel free to contact us.</mj-text>
          </mj-column>
        </mj-section>

        <mj-section>
          <mj-column>
            <mj-text font-size="14px">Thanks for shopping with us!</mj-text>
          </mj-column>
        </mj-section>
      </mj-body>
    </mjml>
    """
  end
end

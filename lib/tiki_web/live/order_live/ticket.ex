defmodule TikiWeb.OrderLive.Ticket do
  use TikiWeb, :live_view

  alias Tiki.Orders

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <.back navigate={@return_to}>
        {gettext("Back to order")}
      </.back>

      <div class="">
        <div class="flex flex-col gap-4 sm:flex-row sm:gap-8">
          <div class="size-48">
            <.svg_qr data={@ticket.id} />
          </div>

          <div class="flex flex-col gap-4 sm:flex-row sm:gap-8">
            <div class="flex flex-col gap-2">
              <h2 class="text-foreground text-xl font-semibold tracking-tight">
                {gettext("Your ticket to %{event}",
                  event: @ticket.ticket_type.ticket_batch.event.name
                )}
              </h2>
              <h3 class="text-foreground">
                {@ticket.ticket_type.name}
              </h3>
              <p class="text-muted-foreground text-sm">
                {@ticket.ticket_type.description}
              </p>
              <p class="text-muted-foreground text-sm">
                {gettext("Purchased")}
                <!-- TODO: have event date here instead of purchase date -->
                <time datetime={@ticket.inserted_at}>
                  {Tiki.Cldr.DateTime.to_string!(@ticket.inserted_at, format: :short)}
                </time>
              </p>
            </div>
          </div>
        </div>

        <h2 class="text-foreground text-base/7 mt-8 font-semibold">
          {gettext("Ticket information")}
        </h2>
        <hr role="presentation" class="border-border mt-4 w-full border-t" />
        <dl class="text-sm/6 grid grid-cols-1 sm:grid-cols-[min(50%,theme(spacing.80))_auto] sm:text-sm/6">
          <%= for qr <- @ticket.form_response.question_responses do %>
            <dt class="border-border text-muted-foreground col-start-1 border-t pt-3 first:border-none sm:py-3">
              {qr.question.name}
            </dt>
            <dd class="text-foreground pt-1 pb-3 sm:border-border sm:[&amp;:nth-child(2)]:border-none sm:border-t sm:py-3">
              {qr}
            </dd>
          <% end %>
        </dl>
      </div>

      <.link navigate={@form_url}>
        <.button variant="secondary">
          {gettext("Edit details")}
        </.button>
      </.link>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def mount(%{"id" => ticket_id} = _params, _session, socket) do
    # TODO: fix this preloading nonsense
    ticket =
      Orders.get_ticket!(ticket_id)
      |> Tiki.Repo.preload(
        form_response: [question_responses: :question],
        ticket_type: [ticket_batch: :event]
      )

    order_url =
      case socket.assigns.live_action do
        :embedded_show -> ~p"/embed/orders/#{ticket.order_id}"
        :show -> ~p"/orders/#{ticket.order_id}"
      end

    if ticket.form_response do
      form_url =
        case socket.assigns.live_action do
          :embedded_show ->
            ~p"/embed/tickets/#{ticket}/form?return_to=#{~p"/embed/tickets/#{ticket}"}"

          :show ->
            ~p"/tickets/#{ticket}/form?return_to=#{~p"/tickets/#{ticket}"}"
        end

      {:ok,
       assign(socket, ticket: ticket)
       |> assign(form_url: form_url)
       |> assign(return_to: order_url)}
    else
      form_url =
        case socket.assigns.live_action do
          :embedded_show ->
            ~p"/embed/tickets/#{ticket}/form?return_to=#{~p"/embed/orders/#{ticket.order_id}"}"

          :show ->
            ~p"/tickets/#{ticket}/form?return_to=#{~p"/orders/#{ticket.order_id}"}"
        end

      {:ok, push_navigate(socket, to: form_url)}
    end
  end
end

defmodule TikiWeb.OrderLive.Show do
  use TikiWeb, :live_view

  alias Tiki.Orders

  import TikiWeb.Component.Card

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="space-y-2 px-4 sm:flex sm:items-baseline sm:justify-between sm:space-y-0 sm:px-0">
      <div class="flex sm:items-baseline sm:space-x-4">
        <h1 class="text-foreground text-2xl font-bold tracking-tight sm:text-3xl">
          <%= gettext("Thank you for your order!") %>
        </h1>
        <!-- TODO: Reciept link -->
        <.link
          href="#"
          class="text-secondary-foreground hidden text-sm font-medium hover:text-secondary-foreground/80 sm:block"
        >
          <%= gettext("View receipt") %> <span aria-hidden="true"> &rarr;</span>
        </.link>
      </div>
      <p class="text-muted-foreground text-sm">
        <!-- TODO: Proper time  -->
        Order placed
        <time datetime={@order.updated_at}>
          <%= Tiki.Cldr.DateTime.to_string!(@order.updated_at, format: :short) %>
        </time>
      </p>
      <!-- TODO: Reciept link -->
      <.link href="#" class="text-sm font-medium sm:hidden">
        <%= gettext("View receipt") %> <span aria-hidden="true"> &rarr;</span>
      </.link>
    </div>

    <div class="mt-6">
      <h2 class="sr-only"><%= gettext("Tickets") %></h2>

      <div class="space-y-4 md:space-y-8">
        <.card :for={ticket <- @order.tickets}>
          <div class="px-4 py-6 sm:px-6 lg:grid lg:grid-cols-12 lg:gap-x-8 lg:p-8">
            <div class="sm:flex lg:col-span-7">
              <div>
                <.link navigate={~p"/tickets/#{ticket}"}>
                  <h3 class="text-foreground text-base font-medium">
                    <%= ticket.ticket_type.name %>
                  </h3>
                </.link>
                <p class="text-foreground mt-2 text-sm font-medium">
                  <%= ticket.ticket_type.price %> SEK
                </p>
                <p class="text-muted-foreground mt-3 text-sm">
                  <%= ticket.ticket_type.description %>
                </p>
              </div>
            </div>
            <div :if={ticket.form_response} class="mt-6 lg:col-span-5 lg:mt-0">
              <dl class="grid grid-cols-2 gap-x-6 text-sm">
                <div>
                  <dt class="text-foreground font-medium">
                    <%= gettext("Name") %>
                  </dt>
                  <dd class="text-muted-foreground mt-3">
                    <span class="block">
                      <%= find_in_response(ticket.form_response, "namn") %>
                    </span>
                  </dd>
                </div>
                <div>
                  <dt class="text-foreground font-medium">
                    <%= gettext("Contact information") %>
                  </dt>
                  <dd class="text-muted-foreground mt-3 space-y-3">
                    <p>
                      <%= find_in_response(ticket.form_response, "email") %>
                    </p>
                  </dd>
                </div>
              </dl>
            </div>
          </div>

          <div
            :if={!ticket.form_response}
            class="border-border flex flex-row items-center justify-between border-t px-4 py-6 sm:px-6 lg:gap-x-8 lg:p-8"
          >
            <p class="text-sm font-medium">
              <%= gettext("You need to fill in attendance information for this ticket") %>
            </p>

            <.link navigate={~p"/tickets/#{ticket.id}/form"}>
              <.button variant="secondary">
                <%= gettext("Fill in") %>
              </.button>
            </.link>
          </div>
        </.card>
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, _session, socket) do
    # TODO: fix this preloading nonsense
    order =
      Orders.get_order!(id)
      |> Tiki.Repo.preload(tickets: [form_response: [question_responses: [:question]]])

    {:ok, assign(socket, order: order)}
  end

  defp find_in_response(response, question) do
    response.question_responses
    |> Enum.find(%{}, fn qr -> String.downcase(qr.question.name) == question end)
    |> Map.get(:answer, "")
  end
end

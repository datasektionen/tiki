defmodule TikiWeb.AdminLive.Reports.Index do
  use TikiWeb, :live_view

  alias Tiki.Events
  alias Tiki.Tickets
  alias Tiki.Policy
  alias Tiki.Reports
  alias Tiki.Reports.ReportParams

  alias Tiki.Localizer

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="print:hidden">
        <h1 class="text-3xl font-bold">{gettext("Reports")}</h1>
        <p class="text-muted-foreground mt-2 text-sm">
          {gettext(
            "Generate ticket sales reports for your events. Reports are displayed in English only"
          )}
        </p>
      </div>

      <div class="bg-card border-border rounded-lg border p-6 print:hidden">
        <h2 class="mb-4 text-lg font-semibold">{gettext("Generate Report")}</h2>

        <.form
          for={@form}
          phx-submit="generate_report"
          phx-change="change_event"
          id="report-form"
          class="space-y-6"
        >
          <div class="grid grid-cols-1 gap-6 md:grid-cols-2">
            <.live_component
              id="event-search-component"
              module={TikiWeb.LiveComponents.SearchCombobox}
              search_fn={&Events.search_events/1}
              all_fn={&Events.list_events/1}
              map_fn={fn event -> {event.id, Localizer.localize(event).name} end}
              field={@form[:event_id]}
              label={gettext("Event")}
              chosen={@form[:event_id].value}
              placeholder={gettext("All Events")}
              empty_option={{"", gettext("All Events")}}
              notify_fn={&notify_parent/1}
            />

            <%= if @form[:event_id].value && @form[:event_id].value != "" && !Enum.empty?(@ticket_types) do %>
              <div>
                <label class="mb-0.5 block text-sm font-medium">{gettext("Ticket Types")}</label>
                <div class="text-muted-foreground mb-2 block text-xs">
                  {gettext("Leave blank to include all ticket types")}
                </div>
                <div class="border-input max-h-40 space-y-2 overflow-y-auto rounded-md border p-3">
                  <label :for={tt <- @ticket_types} class="flex items-center gap-2">
                    <input
                      type="checkbox"
                      name="report_params[ticket_type_ids][]"
                      value={tt.id}
                      checked={tt.id in (@form[:ticket_type_ids].value || [])}
                      class="border-primary text-primary bg-background size-4 rounded-sm shadow-sm checked:bg-primary focus:ring-0 dark:checked:bg-dark-checkmark dark:checked:text-primary"
                    />
                    <span class="text-sm">{Localizer.localize(tt).name}</span>
                  </label>
                </div>
              </div>
            <% end %>
          </div>

          <div class="grid grid-cols-1 gap-6 md:grid-cols-2">
            <.input
              field={@form[:start_date]}
              type="date"
              label={gettext("Start Date")}
              description={gettext("Inclusive. Leave blank for unbounded dates")}
            />

            <.input
              field={@form[:end_date]}
              type="date"
              label={gettext("End Date")}
              description={gettext("Inclusive. Leave blank for unbounded dates")}
            />
          </div>

          <div class="grid grid-cols-1 gap-6 md:grid-cols-2">
            <.input
              field={@form[:payment_type]}
              type="select"
              label={gettext("Payment Methods")}
              options={[
                {"All", ""},
                {"Stripe", "stripe"},
                {"Swish", "swish"}
              ]}
            />
            <.input
              field={@form[:include_details]}
              type="checkbox"
              label={gettext("Include detailed transactions")}
              description={gettext("Shows individual ticket purchases (increases report size)")}
            />
          </div>

          <div class="flex justify-end gap-3">
            <.button
              type="submit"
              disabled={@loading}
            >
              <%= if @loading do %>
                <span class="mr-2 inline-block animate-spin">⏳</span> {gettext("Generating...")}
              <% else %>
                {gettext("Generate Report")}
              <% end %>
            </.button>
          </div>
        </.form>
      </div>

      <%= if @report_data do %>
        <div class="space-y-6 print:space-y-4">
          <div class="flex items-center justify-between print:hidden">
            <h2 class="text-xl font-semibold">Report Results</h2>
            <button
              onclick="window.print()"
              class="border-input rounded-md border px-3 py-1 text-sm hover:bg-secondary"
            >
              {gettext("Print / Save as PDF")}
            </button>
          </div>

          <%!-- Print header --%>
          <div class="mb-6 hidden space-y-2 print:block">
            <h1 class="text-2xl font-bold">Tiki Sales Report</h1>
            <p class="text-sm">
              <strong>Generated:</strong> {time_to_string(@report_data.generated_at,
                locale: :en,
                format: :long
              )}
            </p>
            <p class="text-sm">
              <strong>Events:</strong> {format_event_list(@report_data.summary)}
            </p>
            <p class="text-sm">
              <strong>Period:</strong>
              {format_report_date_range(@form[:start_date].value, @form[:end_date].value)}
            </p>
            <p class="text-sm">
              <strong>Payment Methods:</strong> {format_payment_type(@form[:payment_type].value)}
            </p>
          </div>

    <!-- Summary Table -->
          <div class="bg-card border-border overflow-hidden rounded-lg border print:border-gray-300">
            <table class="w-full text-sm">
              <thead class="bg-muted print:bg-gray-100">
                <tr>
                  <th class="px-4 py-2 text-left font-semibold">Ticket</th>
                  <th class="px-2 py-2 text-right font-semibold">#</th>
                  <th class="px-4 py-2 text-right font-semibold">Excl. VAT</th>
                  <th class="px-2 py-2 text-right font-semibold">VAT</th>
                  <th class="px-4 py-2 text-right font-semibold">Incl. VAT</th>
                </tr>
              </thead>
              <tbody>
                <%= for event_summary <- @report_data.summary do %>
                  <!-- Event header -->
                  <tr class="border-border bg-muted/60 border-t-2 print:border-gray-300 print:bg-gray-50">
                    <td colspan="5" class="px-4 py-2 font-semibold">
                      Event: {event_summary.event_name}
                    </td>
                  </tr>

    <!-- Ticket types for this event -->
                  <%= for item <- event_summary.items do %>
                    <tr class="border-border border-t hover:bg-secondary print:border-gray-300 print:hover:bg-transparent">
                      <td class="px-4 py-2">{item.ticket_type_name}</td>
                      <td class="px-2 py-2 text-right tabular-nums">{item.quantity}</td>
                      <td class="px-4 py-2 text-right tabular-nums">
                        {format_accounting_sek(item.total_revenue)}
                      </td>
                      <td class="px-2 py-2 text-right tabular-nums">
                        {format_accounting_sek(0)}
                      </td>
                      <td class="px-4 py-2 text-right tabular-nums">
                        {format_accounting_sek(item.total_revenue)}
                      </td>
                    </tr>
                  <% end %>

    <!-- Event subtotal -->
                  <tr class="border-border bg-muted/30 border-t font-semibold print:border-gray-300 print:bg-gray-50">
                    <td class="px-4 py-2">Subtotal</td>
                    <td class="px-2 py-2 text-right tabular-nums">{event_summary.total_quantity}</td>
                    <td class="px-4 py-2 text-right tabular-nums">
                      {format_accounting_sek(event_summary.total_revenue)}
                    </td>
                    <td class="px-2 py-2 text-right tabular-nums">
                      {format_accounting_sek(0)}
                    </td>
                    <td class="px-4 py-2 text-right tabular-nums">
                      {format_accounting_sek(event_summary.total_revenue)}
                    </td>
                  </tr>
                <% end %>

    <!-- Grand total -->
                <tr class="border-border bg-muted border-t-2 font-semibold print:border-gray-400 print:bg-gray-100">
                  <td class="px-4 py-2">Grand total</td>
                  <td class="px-2 py-2 text-right tabular-nums">{@report_data.total_tickets}</td>
                  <td class="px-4 py-2 text-right tabular-nums">
                    {format_accounting_sek(@report_data.grand_total)}
                  </td>
                  <td class="px-2 py-2 text-right tabular-nums">
                    {format_accounting_sek(0)}
                  </td>
                  <td class="px-4 py-2 text-right tabular-nums">
                    {format_accounting_sek(@report_data.grand_total)}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

    <!-- Detailed Transactions Table -->
          <%= if @form[:include_details].value && !Enum.empty?(@report_data.details) do %>
            <div class="bg-card border-border overflow-hidden rounded-lg border print:page-break-before print:mt-0 print:border-gray-300">
              <div class="border-border bg-muted border-b px-4 py-3 print:border-gray-300 print:bg-gray-100">
                <h3 class="font-semibold">Detailed Transactions</h3>
              </div>
              <div class="space-y-4 p-4 print:space-y-6">
                <%= for detail <- @report_data.details do %>
                  <div class="border-border border-b pb-4 last:border-b-0 print:border-gray-300 print:pb-6">
                    <div class="grid grid-cols-2 gap-4 text-sm md:grid-cols-3">
                      <div>
                        <p class="text-muted-foreground text-xs">Date</p>
                        <p>{time_to_string(detail.paid_at, locale: :en)}</p>
                      </div>
                      <div>
                        <p class="text-muted-foreground text-xs">Event</p>
                        <p>{detail.event_name}</p>
                      </div>
                      <div>
                        <p class="text-muted-foreground text-xs">Order ID</p>
                        <.link navigate={
                          ~p"/admin/events/#{detail.event_id}/orders/#{detail.order_id}"
                        }>
                          <p class="break-all font-medium hover:underline print:font-normal">
                            {detail.order_id}
                          </p>
                        </.link>
                      </div>
                      <div>
                        <p class="text-muted-foreground text-xs">Ticket Type</p>
                        <p>{detail.ticket_type_name}</p>
                      </div>
                      <div>
                        <p class="text-muted-foreground text-xs">Buyer</p>
                        <p>{detail.buyer_name}</p>
                      </div>
                      <div>
                        <p class="text-muted-foreground text-xs">Amount</p>
                        <p class="">{format_accounting_sek(detail.price)}</p>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>

    <style>
      @media print {
        .print\:hidden { display: none !important; }
        .print\:block { display: block !important; }
        .print\:page-break-before { page-break-before: always; }
        .print\:font-normal { font-weight: normal !important; }
        .print\:mt-0 { margin-top: 0; }
        .print\:space-y-6 > * + * { margin-top: 1.5rem; }
        body { margin: 0; padding: 12px; font-size: 12pt; }
        table { page-break-inside: avoid; }
        @page {
          size: A4;
          margin: 8mm;
        }
      }
    </style>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    %{current_scope: scope} = socket.assigns

    with :ok <- Policy.authorize(:report_generate, scope.user, scope.team) do
      {:ok,
       socket
       |> assign(:page_title, gettext("Reports"))
       |> assign(:breadcrumbs, [{"Payments", ""}, {"Reports", ~p"/admin/reports"}])
       |> assign(:ticket_types, [])
       |> assign(:form, to_form(ReportParams.changeset()))
       |> assign(:report_data, nil)
       |> assign(:loading, false)}
    else
      {:error, :unauthorized} ->
        {:ok,
         socket
         |> put_flash(:error, "You are not authorized to generate reports.")
         |> redirect(to: ~p"/admin")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("change_event", %{"report_params" => params}, socket) do
    event_id = params["event_id"]

    ticket_types =
      if event_id && event_id != "" do
        Tickets.get_available_ticket_types(event_id)
        |> Enum.uniq_by(& &1.id)
      else
        []
      end

    form = to_form(ReportParams.changeset(params))

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:ticket_types, ticket_types)}
  end

  def handle_event("generate_report", %{"report_params" => params}, socket) do
    %{current_scope: scope} = socket.assigns

    case Reports.queue_report_generation(scope, params) do
      {:ok, _job} ->
        changeset = ReportParams.changeset(params)

        {:noreply,
         socket
         |> assign(:form, to_form(changeset))
         |> assign(:loading, true)
         |> assign(:report_data, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:report_result, :ok, report}, socket) do
    {:noreply,
     socket
     |> assign(:loading, false)
     |> assign(:report_data, report)}
  end

  def handle_info({:report_result, :error, %{message: message}}, socket) do
    {:noreply,
     socket
     |> assign(:loading, false)
     |> put_flash(:error, message)}
  end

  def handle_info({TikiWeb.AdminLive.Reports.Index, {:event_selected, {event_id, _}}}, socket) do
    ticket_types =
      if event_id && event_id != "" do
        Tickets.get_available_ticket_types(event_id)
        |> Enum.uniq_by(& &1.id)
      else
        []
      end

    # Update the form with the selected event
    form = to_form(ReportParams.changeset(%{"event_id" => event_id}))

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:ticket_types, ticket_types)}
  end

  defp format_report_date_range(nil, nil), do: "all time"

  defp format_report_date_range(start_date, nil),
    do: "from #{time_to_string(start_date, locale: :en)}"

  defp format_report_date_range(nil, end_date),
    do: "until #{time_to_string(end_date, locale: :en)}"

  defp format_report_date_range("", ""), do: "All dates"

  defp format_report_date_range("", end_date),
    do: "Before #{time_to_string(end_date, locale: :en)}"

  defp format_report_date_range(start_date, ""),
    do: "After #{time_to_string(start_date, locale: :en)}"

  defp format_report_date_range(start_date, end_date) do
    "#{Date.to_string(start_date)} to #{Date.to_string(end_date)}"
  end

  defp format_event_list(summary) do
    summary
    |> Enum.map(& &1.event_name)
    |> Enum.join(", ")
  end

  defp format_payment_type(""), do: "All"
  defp format_payment_type("stripe"), do: "Stripe"
  defp format_payment_type("swish"), do: "Swish"

  defp notify_parent(msg) do
    send(self(), {__MODULE__, {:event_selected, msg}})
  end

  defp format_accounting_sek(amount) do
    format_sek(amount, locale: "sv", currency_digits: :accounting)
  end
end

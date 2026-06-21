defmodule TikiWeb.EventLive.ReleaseSignupComponent do
  use TikiWeb, :live_component

  alias Tiki.Releases

  import TikiWeb.Component.Badge

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div class="flex flex-col">
      <div class="bg-accent rounded-xl">
        <div class="flex flex-col gap-2 px-4 py-4">
          <div>
            <.badge variant="outline">
              {gettext("Status:")} {signup_status_label(@signup)}
              <.tooltip class="flex justify-center pl-1">
                <.icon name="hero-information-circle" class="size-3.5" />
                <.tooltip_content
                  id={@signup.id <> "tooltip"}
                  side="right"
                  class="max-w-64 size-fit z-20 w-max whitespace-normal text-sm font-normal"
                >
                  <div class="size-max max-w-64 w-full w-fit whitespace-pre-line" phx-no-format>{signup_status_description(@signup)}</div>
                </.tooltip_content>
              </.tooltip>
            </.badge>
          </div>

          <ul class="flex flex-col gap-1">
            <li :for={item <- @signup.items} class="text-sm font-semibold">
              {item.quantity}× {item.ticket_type.name}
            </li>
          </ul>

          <p class="text-muted-foreground flex flex-row text-sm">
            {gettext("Draw at %{time}",
              time: time_to_string(lottery_end(@release), format: :short)
            )}
          </p>

          <.button
            :if={@release.drawn_at == nil}
            variant="outline"
            phx-click="cancel-signup"
            phx-target={@myself}
            class="w-full"
          >
            {gettext("Cancel")}
          </.button>

          <%!-- <div :if={@phase == :purchase and @signup.status in [:drawn, :seeded] and @signup.order_id}> --%>
          <div :if={@signup.status in [:drawn, :seeded] and @signup.order_id}>
            <p class="mb-3 text-sm">
              {gettext("You've been selected! Pay before %{time} to claim your spot.",
                time: time_to_string(purchase_end(@release), format: :short)
              )}
            </p>
            <.link navigate={~p"/events/#{@release.event_id}/purchase/#{@signup.order_id}"}>
              <.button class="w-full">{gettext("Pay now")}</.button>
            </.link>
          </div>
        </div>
      </div>

      <p :if={@error} class="text-sm text-red-700">{@error}</p>
    </div>
    """
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    {:ok, assign(socket, assigns) |> assign(error: nil)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("cancel-signup", _, socket) do
    %{signup: signup} = socket.assigns

    case Releases.cancel_signup(socket.assigns.current_scope, signup.id) do
      {:ok, _} ->
        # PubSub broadcast notifies Show, which clears user_signup and unmounts this component
        {:noreply, socket}

      {:error, :not_open} ->
        {:noreply, assign(socket, error: gettext("The signup window has already closed."))}

      {:error, _} ->
        {:noreply, assign(socket, error: gettext("Could not cancel signup."))}
    end
  end

  defp lottery_end(release) do
    DateTime.add(release.opens_at, release.signup_window_minutes, :minute)
  end

  defp purchase_end(release) do
    release |> lottery_end() |> DateTime.add(release.purchase_window_minutes, :minute)
  end

  defp signup_status_label(%{release: %{drawn_at: nil}}), do: gettext("Queued")

  defp signup_status_label(%{status: label}) when label in [:drawn, :seeded],
    do: gettext("Selected")

  defp signup_status_label(%{status: label}) when label in [:lost, :rejected],
    do: gettext("Not selected")

  defp signup_status_description(%{release: %{drawn_at: nil}}),
    do: gettext("You're in the queue waiting for allocation. Check back later.")

  defp signup_status_description(%{status: label}) when label in [:drawn, :seeded],
    do:
      gettext(
        "You have been selected. Be sure to pay within the allocated time to claim your tickets."
      )

  defp signup_status_description(%{status: label}) when label in [:lost, :rejected],
    do:
      gettext(
        "Unfortunately, you did were not allocated a spot in this release. Feel free to check back later to find if there are still tickets available."
      )
end

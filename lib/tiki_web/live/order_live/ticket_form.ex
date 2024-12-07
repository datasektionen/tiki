defmodule TikiWeb.OrderLive.TicketForm do
  use TikiWeb, :live_view

  alias Tiki.Orders
  alias Tiki.Forms

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div>
      <.back navigate={~p"/orders/#{@ticket.order_id}"}>
        {gettext("Back to order")}
      </.back>
    </div>
    <div class="mt-4 space-y-8">
      <div>
        <h2 class="font-semibold">{gettext("Fill in ticket information")}</h2>
        <p class="text-muted-foreground text-sm">
          {gettext("We need some information from you to help us organize the event.")}
        </p>
      </div>
      <.form for={@response_form} phx-submit="save" phx-change="validate" class="w-full">
        <div class="border-border mt-4 grid grid-cols-1 gap-6 border-b pb-8 sm:grid-cols-6">
          <div :for={question <- @form.questions} class={styling_for_question(question)}>
            <.form_input question={question} field={@response_form[String.to_atom("#{question.id}")]} />
            <div :if={question.description} class="text-muted-foreground mt-2 text-sm">
              {question.description}
            </div>
          </div>
        </div>
        <div class="mt-4 flex flex-row justify-end">
          <.button phx-disable-with={gettext("Saving...")}>
            {gettext("Save")}
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, _session, socket) do
    ticket =
      Orders.get_ticket!(id)

    form = Forms.get_form!(ticket.ticket_type.form_id)

    changeset =
      Forms.get_form_changeset!(
        ticket.ticket_type.form_id,
        ticket.form_response || %{}
      )

    {:ok,
     assign(socket, :ticket, ticket)
     |> assign(:form, form)
     |> assign(:response, ticket.form_response)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"form_response" => response_params}, socket) do
    response_params = flatten_response(response_params)

    changeset =
      Forms.get_form_changeset!(socket.assigns.form.id, response_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"form_response" => response_params}, socket) do
    save_form(socket, socket.assigns.response, response_params)
  end

  defp save_form(socket, nil = _prev_response, attrs) do
    attrs = flatten_response(attrs)

    case Forms.submit_response(socket.assigns.form.id, socket.assigns.ticket.id, attrs) do
      {:ok, _response} ->
        {:noreply,
         put_flash(socket, :info, gettext("Saved response"))
         |> push_navigate(to: ~p"/orders/#{socket.assigns.ticket.order_id}")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_form(socket, prev_response, attrs) do
    attrs = flatten_response(attrs)

    case Forms.update_form_response(prev_response, attrs) do
      {:ok, _response} ->
        {:noreply,
         put_flash(socket, :info, gettext("Saved response"))
         |> push_navigate(to: ~p"/orders/#{socket.assigns.ticket.order_id}")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp flatten_response(response) do
    Enum.reduce(response, response, fn {q, a}, acc ->
      case a do
        a when is_map(a) ->
          list = Map.filter(a, fn {_, sel} -> sel == "true" end) |> Map.keys()
          Map.put(acc, q, list)

        _ ->
          acc
      end
    end)
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :response_form, to_form(changeset, as: :form_response))
  end

  defp styling_for_question(%{type: :multi_select}), do: "sm:col-span-4"
  defp styling_for_question(%{type: :select}), do: "sm:col-span-3"
  defp styling_for_question(%{type: :text_area}), do: "sm:col-span-6"
  defp styling_for_question(%{type: :text}), do: "sm:col-span-3"
end

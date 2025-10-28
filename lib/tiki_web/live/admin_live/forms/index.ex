defmodule TikiWeb.AdminLive.Forms.Index do
  use TikiWeb, :live_view

  alias Tiki.Forms
  alias Tiki.Localizer

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.header>
      {gettext("Forms")}
      <:subtitle>
        {gettext("Manage forms for your event.")}
      </:subtitle>
      <:actions>
        <.link navigate={~p"/admin/events/#{@event}/forms/new"}>
          <.button>{gettext("New form")}</.button>
        </.link>
      </:actions>
    </.header>

    <.table id="forms" rows={@streams.forms}>
      <:col :let={{_id, form}} label={gettext("Name")}>{form.name}</:col>

      <:action :let={{_id, form}}>
        <.link navigate={~p"/admin/events/#{@event}/forms/#{form}/edit"}>
          {gettext("Edit")}
        </.link>
      </:action>
      <:action :let={{id, form}}>
        <.link
          phx-click={JS.push("delete", value: %{id: form.id}) |> hide("##{id}")}
          data-confirm={gettext("Are you sure?")}
        >
          {gettext("Delete")}
        </.link>
      </:action>
    </.table>
    """
  end

  @impl Phoenix.LiveView
  def mount(%{"event_id" => event_id}, _session, socket) do
    event = Tiki.Events.get_event!(event_id)

    with :ok <- Tiki.Policy.authorize(:event_view, socket.assigns.current_user, event) do
      forms = Forms.list_forms_for_event(event_id)

      {:ok,
       assign(socket, event: event)
       |> stream(:forms, forms)
       |> assign_breadcrumbs([
         {"Dashboard", ~p"/admin"},
         {"Events", ~p"/admin/events"},
         {Localizer.localize(event).name, ~p"/admin/events/#{event}"},
         {"Forms", ~p"/admin/events/#{event}/forms"}
       ])}
    else
      {:error, :unauthorized} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You are not authorized to do that."))
         |> redirect(to: ~p"/admin")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    form = Forms.get_form!(id)

    with :ok <-
           Tiki.Policy.authorize(:event_manage, socket.assigns.current_user, socket.assigns.event),
         {:ok, _} = Forms.delete_form(form) do
      {:noreply, stream_delete(socket, :forms, form)}
    else
      {:errorm, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext("You are not authorized to do that."))}
    end
  end
end

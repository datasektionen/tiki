defmodule TikiWeb.AdminLive.Food.Index do
  use TikiWeb, :live_view

  alias Tiki.Foods
  alias Tiki.Foods.Food

  @impl true
  def mount(_params, _session, socket) do
    %{current_user: user, current_team: team} = socket.assigns

    with :ok <- Tiki.Policy.authorize(:team_read, user, team) do
      food_options = Tiki.Foods.list_foods()

      {:ok,
       assign(socket, :form, to_form(Foods.change_food(%Food{})))
       |> stream(:food_options, food_options)}
    else
      {:error, :unauthorized} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You are not authorized to do that."))
         |> redirect(to: ~p"/admin")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply,
     assign_breadcrumbs(
       socket,
       [{"Dashboard", ~p"/admin"}, {"Food preferences", ~p"/admin/food"}]
     )}
  end

  @impl true
  def handle_event("save", %{"food" => food_params}, socket) do
    case Foods.create_food(food_params) do
      {:ok, food} ->
        {:noreply, socket |> put_flash(:info, gettext("Food preference created"))}
        food_options = Tiki.Foods.list_foods()
        stream(socket, :food_options, food_options)

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    %{current_user: user, current_team: team} = socket.assigns

    with :ok <- Tiki.Policy.authorize(:team_update, user, team) do
      food = Tiki.Foods.get_food!(id)

      {:ok, _} = Tiki.Foods.delete_food(food)

      {:noreply, stream_delete(socket, :food_options, food)}
    else
      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, gettext("You are unauthorized to do that."))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      {gettext("Food preferences")}
    </.header>

    <.table id="food" rows={@streams.food_options}>
      <:col :let={{_id, food}} label={gettext("Name")}>{food.name}</:col>
      <:action :let={{id, food}}>
        <.link phx-click={JS.push("delete", value: %{id: food.name}) |> hide("##{id}")} data-confirm={gettext("Are you sure?")}>
          {gettext("Delete")}
        </.link>
      </:action>
    </.table>

    <.simple_form for={@form} id="food-form" phx-submit="save">
      <.input field={@form[:name]} type="text" label={gettext("Name")} />

      <:actions>
        <.button phx-disable-with={gettext("Saving...")}>
          {gettext("Save food")}
        </.button>
      </:actions>
    </.simple_form>
    """
  end
end

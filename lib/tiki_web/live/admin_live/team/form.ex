defmodule TikiWeb.AdminLive.Team.Form do
  use TikiWeb, :live_view

  alias Tiki.Teams
  alias Tiki.Teams.Team

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      {@page_title}
      <:subtitle>Use this form to manage team records in your database.</:subtitle>
    </.header>

    <.simple_form for={@form} id="team-form" phx-change="validate" phx-submit="save">
      <.input field={@form[:name]} type="text" label={gettext("Name")} />
      <:actions>
        <.button phx-disable-with={gettext("Saving...")}>
          {gettext("Save team")}
        </.button>
      </:actions>
    </.simple_form>

    <.back navigate={return_path(@return_to, @team)}>Back</.back>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    team = Teams.get_team!(id)

    socket
    |> assign(:page_title, "Edit Team")
    |> assign(:team, team)
    |> assign(:form, to_form(Teams.change_team(team)))
  end

  defp apply_action(socket, :new, _params) do
    team = %Team{}

    socket
    |> assign(:page_title, "New Team")
    |> assign(:team, team)
    |> assign(:form, to_form(Teams.change_team(team)))
  end

  @impl true
  def handle_event("validate", %{"team" => team_params}, socket) do
    changeset = Teams.change_team(socket.assigns.team, team_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"team" => team_params}, socket) do
    save_team(socket, socket.assigns.live_action, team_params)
  end

  defp save_team(socket, :edit, team_params) do
    case Teams.update_team(socket.assigns.team, team_params) do
      {:ok, team} ->
        {:noreply,
         socket
         |> put_flash(:info, "Team updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, team))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_team(socket, :new, team_params) do
    case Teams.create_team(team_params, members: [socket.assigns.current_user.id]) do
      {:ok, team} ->
        {:noreply,
         socket
         |> put_flash(:info, "Team created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, team))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _team), do: ~p"/admin/teams"
  defp return_path("show", team), do: ~p"/admin/teams/#{team}"
end

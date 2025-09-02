defmodule TikiWeb.AdminLive.Team.Form do
  use TikiWeb, :live_view

  alias Tiki.Teams
  alias Tiki.Teams.Team

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      {@page_title}
      <:subtitle>{gettext("Manage public information about your team.")}</:subtitle>
    </.header>

    <.simple_form for={@form} id="team-form" phx-change="validate" phx-submit="save">
      <.input field={@form[:name]} type="text" label={gettext("Name")} />
      <.input field={@form[:contact_email]} type="text" label={gettext("Contact email")} />
      <.input field={@form[:description]} type="textarea" label={gettext("Description")} />
      <.image_upload upload={@uploads.logo} label={gettext("Team logo")} />

      <:actions>
        <.button phx-disable-with={gettext("Saving...")}>
          {gettext("Save team")}
        </.button>
      </:actions>
    </.simple_form>

    <.back navigate={@return_to}>Back</.back>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> allow_upload(
       :logo,
       accept: ~w[.png .jpeg .jpg],
       max_entries: 1,
       auto_upload: true,
       external: &presign_upload/2
     )
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    team = Teams.get_team!(id)

    with :ok <- Tiki.Policy.authorize(:team_update, socket.assigns.current_user, team) do
      socket
      |> assign(:page_title, gettext("Edit team"))
      |> assign(:return_to, ~p"/admin/teams/")
      |> assign(:team, team)
      |> assign(:form, to_form(Teams.change_team(team)))
      |> assign_breadcrumbs([
        {"Teams", ~p"/admin/teams"},
        {"Edit team", ~p"/admin/teams/#{team}/edit"}
      ])
    else
      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, gettext("You are not authorized to do that."))
        |> redirect(to: ~p"/admin")
    end
  end

  defp apply_action(socket, :manager_edit, _params) do
    team = Teams.get_team!(socket.assigns.current_team.id)

    with :ok <- Tiki.Policy.authorize(:team_update, socket.assigns.current_user, team) do
      socket
      |> assign(:page_title, gettext("Edit team"))
      |> assign(:team, team)
      |> assign(:return_to, ~p"/admin/")
      |> assign(:form, to_form(Teams.change_team(team)))
      |> assign_breadcrumbs([{"Dashboard", ~p"/admin"}, {"Edit team", ~p"/admin/team/edit"}])
    else
      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, gettext("You are not authorized to do that."))
        |> redirect(to: ~p"/admin")
    end
  end

  defp apply_action(socket, :new, _params) do
    with :ok <- Tiki.Policy.authorize(:team_create, socket.assigns.current_user) do
      team = %Team{}

      socket
      |> assign(:page_title, gettext("New Team"))
      |> assign(:team, team)
      |> assign(:return_to, ~p"/admin/teams/")
      |> assign(:form, to_form(Teams.change_team(team)))
      |> assign_breadcrumbs([
        {"Teams", ~p"/admin/teams"},
        {"New team", ~p"/admin/teams/new"}
      ])
    else
      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, gettext("You are not authorized to do that."))
        |> redirect(to: ~p"/admin")
    end
  end

  @impl true
  def handle_event("validate", %{"team" => team_params}, socket) do
    changeset = Teams.change_team(socket.assigns.team, team_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"team" => team_params}, socket) do
    team_params = put_image_url(team_params, socket)
    save_team(socket, socket.assigns.live_action, team_params)
  end

  defp save_team(socket, action, team_params) when action in [:edit, :manager_edit] do
    case Teams.update_team(socket.assigns.team, team_params) do
      {:ok, _team} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Team updated successfully"))
         |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_team(socket, :new, team_params) do
    case Teams.create_team(team_params, members: [socket.assigns.current_user.id]) do
      {:ok, _team} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Team created successfully"))
         |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp put_image_url(params, socket) do
    {completed, []} = uploaded_entries(socket, :logo)

    case completed do
      [] -> params
      [image | _] -> Map.put(params, "logo_url", "uploads/#{image.uuid}")
    end
  end

  defp presign_upload(entry, socket) do
    form = Tiki.S3.presign_form(entry)

    meta = %{
      uploader: "S3",
      key: "uploads/#{entry.uuid}",
      url: form.url,
      fields: Map.new(form.fields)
    }

    {:ok, meta, socket}
  end
end

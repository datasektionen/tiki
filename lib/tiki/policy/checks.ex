defmodule Tiki.Policy.Checks do
  alias Tiki.Accounts
  alias Tiki.Teams
  alias Tiki.Events

  @permission_service Application.compile_env(:tiki, :permission_service_module)

  def hive(%Accounts.Scope{user: user}, _object, permission), do: hive(user, nil, permission)

  def hive(%Accounts.User{} = user, _object, permission) do
    @permission_service.get_permissions(user)
    |> Enum.any?(fn p -> p == permission end)
  end

  def any_team_role(%Accounts.Scope{user: user}, _object, role),
    do: any_team_role(user, nil, role)

  def any_team_role(%Accounts.User{id: id}, _object, role) do
    case Teams.get_memberships_for_user(id) do
      [] -> false
      teams when is_list(teams) -> Enum.any?(teams, &(&1.role == role))
    end
  end

  def team_role(%Accounts.Scope{user: user}, _object, role), do: team_role(user, nil, role)

  def team_role(%Accounts.User{id: id}, %Teams.Team{id: team_id}, role) do
    case Teams.get_members_for_team(team_id) do
      [] ->
        false

      members when is_list(members) ->
        Enum.any?(members, &(&1.user_id == id && &1.role == role))
    end
  end

  def team_role(%Accounts.User{id: id}, %Events.Event{team_id: team_id}, role) do
    case Teams.get_members_for_team(team_id) do
      [] ->
        false

      members when is_list(members) ->
        Enum.any?(members, &(&1.user_id == id && &1.role == role))
    end
  end
end

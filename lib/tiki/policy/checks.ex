defmodule Tiki.Policy.Checks do
  alias Tiki.Accounts
  alias Tiki.Teams
  alias Tiki.Events

  def role(%Accounts.User{role: role}, _object, role), do: true
  def role(_, _, _), do: false

  def pls(%Accounts.User{} = user, _object, permission) do
    Tiki.Pls.get_permissions(user)
    |> Enum.any?(fn p -> p == permission end)
  end

  def any_team_role(%Accounts.User{id: id}, _object, role) do
    case Teams.get_memberships_for_user(id) do
      [] -> false
      teams when is_list(teams) -> Enum.any?(teams, &(&1.role == role))
    end
  end

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

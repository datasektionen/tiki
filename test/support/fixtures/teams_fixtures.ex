defmodule Tiki.TeamsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Tiki.Teams` context.
  """

  @doc """
  Generate a team.
  """
  def team_fixture(attrs \\ %{}) do
    {:ok, team} =
      attrs
      |> Enum.into(%{
        name: "some name",
        contact_email: "turetek@kth.se"
      })
      |> Tiki.Teams.create_team()

    team
  end

  @doc """
  Generate a membership.
  """
  def membership_fixture(attrs \\ %{}) do
    user = Tiki.AccountsFixtures.user_fixture()
    team = Tiki.TeamsFixtures.team_fixture()

    # First add user as admin member directly to DB (bypass authorization for setup)
    admin_membership =
      %Tiki.Teams.Membership{
        team_id: team.id,
        user_id: user.id,
        role: :admin
      }
      |> Tiki.Repo.insert!()

    # Now we can use the scoped function since user is an admin of the team
    scope = Tiki.Accounts.Scope.for_user_and_team(user, team)

    # If creating a new membership (different user), use scoped function
    requested_user_id = attrs[:user_id]

    if requested_user_id == nil || requested_user_id == user.id do
      admin_membership
    else
      {:ok, membership} =
        Tiki.Teams.create_membership(
          scope,
          team.id,
          Enum.into(attrs, %{
            role: :admin,
            user_id: requested_user_id
          })
        )

      membership
    end
  end
end

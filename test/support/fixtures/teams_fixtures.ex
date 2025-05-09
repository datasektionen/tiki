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

    {:ok, membership} =
      attrs
      |> Enum.into(%{
        role: :admin,
        user_id: user.id,
        team_id: team.id
      })
      |> Tiki.Teams.create_membership()

    membership
  end
end

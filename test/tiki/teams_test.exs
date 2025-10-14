defmodule Tiki.TeamsTest do
  use Tiki.DataCase

  alias Tiki.Teams

  describe "teams" do
    alias Tiki.Teams.Team

    import Tiki.TeamsFixtures

    @invalid_attrs %{name: nil}
    @valid_attrs %{name: "some name", contact_email: "some@email.com"}

    test "list_teams/0 returns all teams" do
      team = team_fixture()
      assert Teams.list_teams() == [team]
    end

    test "get_team!/1 returns the team with given id" do
      team = team_fixture()
      assert Teams.get_team!(team.id) == team
    end

    test "create_team/2 with valid data creates a team" do
      assert {:ok, %Team{} = team} = Teams.create_team(@valid_attrs)
      assert team.name == "some name"
    end

    test "create_team/2 with a list of members creates a team and memberships" do
      user_ids = Enum.map(1..3, fn _ -> Tiki.AccountsFixtures.user_fixture().id end)

      assert {:ok, %Team{} = team} = Teams.create_team(@valid_attrs, members: user_ids)
      assert team.name == "some name"

      team = Tiki.Repo.preload(team, members: [:user])

      assert length(team.members) == 3

      assert Enum.all?(team.members, fn %{user_id: user_id} ->
               Enum.member?(user_ids, user_id)
             end)
    end

    test "create_team/2 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Teams.create_team(@invalid_attrs)
    end

    test "create_team/2 with invalid members returns error changeset" do
      user_ids = [12_342_342_134]

      assert {:error, %Ecto.Changeset{}} = Teams.create_team(@valid_attrs, members: user_ids)
    end

    test "update_team/2 with valid data updates the team" do
      team = team_fixture()
      update_attrs = %{name: "some updated name"}

      assert {:ok, %Team{} = team} = Teams.update_team(team, update_attrs)
      assert team.name == "some updated name"
    end

    test "update_team/2 with invalid data returns error changeset" do
      team = team_fixture()
      assert {:error, %Ecto.Changeset{}} = Teams.update_team(team, @invalid_attrs)
      assert team == Teams.get_team!(team.id)
    end

    test "delete_team/1 deletes the team" do
      team = team_fixture()
      assert {:ok, %Team{}} = Teams.delete_team(team)
      assert_raise Ecto.NoResultsError, fn -> Teams.get_team!(team.id) end
    end

    test "change_team/1 returns a team changeset" do
      team = team_fixture()
      assert %Ecto.Changeset{} = Teams.change_team(team)
    end
  end

  describe "team_membership" do
    alias Tiki.Teams.Membership

    import Tiki.TeamsFixtures

    @invalid_attrs %{role: nil}

    @valid_attrs %{name: "some name", contact_email: "some@email.com"}

    test "list_team_membership/0 returns all team_membership" do
      membership = membership_fixture()
      assert Teams.list_team_membership() == [membership]
    end

    test "get_membership!/1 returns the membership with given id" do
      membership = membership_fixture() |> Tiki.Repo.preload([:user, :team])
      assert Teams.get_membership!(membership.id) == membership
    end

    test "create_membership/1 with valid data creates a membership" do
      team = team_fixture()
      admin_user = Tiki.AccountsFixtures.user_fixture()
      new_user = Tiki.AccountsFixtures.user_fixture()

      # Make admin_user an admin of the team
      %Membership{user_id: admin_user.id, team_id: team.id, role: :admin}
      |> Tiki.Repo.insert!()

      scope = Tiki.Accounts.Scope.for_user_and_team(admin_user, team)
      valid_attrs = %{role: :admin, user_id: new_user.id}

      assert {:ok, %Membership{} = membership} =
               Teams.create_membership(scope, team.id, valid_attrs)

      assert membership.role == :admin
      assert membership.user_id == new_user.id
    end

    test "create_membership/1 with invalid data returns error changeset" do
      team = team_fixture()
      admin_user = Tiki.AccountsFixtures.user_fixture()

      # Make admin_user an admin of the team
      %Membership{user_id: admin_user.id, team_id: team.id, role: :admin}
      |> Tiki.Repo.insert!()

      scope = Tiki.Accounts.Scope.for_user_and_team(admin_user, team)

      assert {:error, %Ecto.Changeset{}} = Teams.create_membership(scope, team.id, @invalid_attrs)
    end

    test "update_membership/2 with valid data updates the membership" do
      membership = membership_fixture() |> Tiki.Repo.preload([:user, :team])
      scope = Tiki.Accounts.Scope.for_user_and_team(membership.user, membership.team)
      update_attrs = %{role: :member}

      assert {:ok, %Membership{} = membership} =
               Teams.update_membership(scope, membership, update_attrs)

      assert membership.role == :member
    end

    test "update_membership/2 with invalid data returns error changeset" do
      membership = membership_fixture() |> Tiki.Repo.preload([:user, :team])
      scope = Tiki.Accounts.Scope.for_user_and_team(membership.user, membership.team)

      assert {:error, %Ecto.Changeset{}} =
               Teams.update_membership(scope, membership, @invalid_attrs)

      assert membership == Teams.get_membership!(membership.id)
    end

    test "delete_membership/1 deletes the membership" do
      membership = membership_fixture()
      assert {:ok, %Membership{}} = Teams.delete_membership(membership)
      assert_raise Ecto.NoResultsError, fn -> Teams.get_membership!(membership.id) end
    end

    test "change_membership/1 returns a membership changeset" do
      membership = membership_fixture()
      assert %Ecto.Changeset{} = Teams.change_membership(membership)
    end

    test "get_teams_for_user/1 returns the teams for a user" do
      user = Tiki.AccountsFixtures.user_fixture()
      {:ok, team} = Teams.create_team(@valid_attrs, members: [user.id])

      assert Teams.get_teams_for_user(user.id) == [team]
    end

    test "get_members_for_team/1 returns the members for a team" do
      user = Tiki.AccountsFixtures.user_fixture()
      {:ok, team} = Teams.create_team(@valid_attrs, members: [user.id])

      assert Teams.get_members_for_team(team.id) |> Enum.map(& &1.user) == [user]
    end

    test "create_membership/3 rejects unauthorized user" do
      team = team_fixture()
      unauthorized_user = Tiki.AccountsFixtures.user_fixture()
      new_user = Tiki.AccountsFixtures.user_fixture()

      # unauthorized_user is NOT a member of the team
      scope = Tiki.Accounts.Scope.for_user_and_team(unauthorized_user, team)
      valid_attrs = %{role: :admin, user_id: new_user.id}

      assert {:error, :unauthorized} = Teams.create_membership(scope, team.id, valid_attrs)
    end

    test "update_membership/3 rejects unauthorized user" do
      membership = membership_fixture() |> Tiki.Repo.preload([:user, :team])
      unauthorized_user = Tiki.AccountsFixtures.user_fixture()

      # unauthorized_user is NOT a member of the team
      scope = Tiki.Accounts.Scope.for_user_and_team(unauthorized_user, membership.team)

      assert {:error, :unauthorized} =
               Teams.update_membership(scope, membership, %{role: :member})
    end
  end
end

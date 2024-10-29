defmodule Tiki.TeamsTest do
  use Tiki.DataCase

  alias Tiki.Teams

  describe "teams" do
    alias Tiki.Teams.Team

    import Tiki.TeamsFixtures

    @invalid_attrs %{name: nil}

    test "list_teams/0 returns all teams" do
      team = team_fixture()
      assert Teams.list_teams() == [team]
    end

    test "get_team!/1 returns the team with given id" do
      team = team_fixture()
      assert Teams.get_team!(team.id) == team
    end

    test "create_team/1 with valid data creates a team" do
      valid_attrs = %{name: "some name"}

      assert {:ok, %Team{} = team} = Teams.create_team(valid_attrs)
      assert team.name == "some name"
    end

    test "create_team/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Teams.create_team(@invalid_attrs)
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

    test "list_team_membership/0 returns all team_membership" do
      membership = membership_fixture()
      assert Teams.list_team_membership() == [membership]
    end

    test "get_membership!/1 returns the membership with given id" do
      membership = membership_fixture()
      assert Teams.get_membership!(membership.id) == membership
    end

    test "create_membership/1 with valid data creates a membership" do
      valid_attrs = %{role: :admin}

      assert {:ok, %Membership{} = membership} = Teams.create_membership(valid_attrs)
      assert membership.role == :admin
    end

    test "create_membership/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Teams.create_membership(@invalid_attrs)
    end

    test "update_membership/2 with valid data updates the membership" do
      membership = membership_fixture()
      update_attrs = %{role: :member}

      assert {:ok, %Membership{} = membership} = Teams.update_membership(membership, update_attrs)
      assert membership.role == :member
    end

    test "update_membership/2 with invalid data returns error changeset" do
      membership = membership_fixture()
      assert {:error, %Ecto.Changeset{}} = Teams.update_membership(membership, @invalid_attrs)
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
  end
end

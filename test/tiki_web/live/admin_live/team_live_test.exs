defmodule TikiWeb.AdminLive.TeamTest do
  use TikiWeb.ConnCase

  import Phoenix.LiveViewTest
  import Tiki.TeamsFixtures

  @create_attrs %{name: "some name"}
  @update_attrs %{name: "some updated name"}
  @invalid_attrs %{name: nil}

  defp create_team(_) do
    team = team_fixture()
    %{team: team}
  end

  describe "Index" do
    setup [:create_team]

    test "lists all teams", %{conn: conn, team: team} do
      {:ok, _index_live, html} = live(conn, ~p"/admin/teams")

      assert html =~ "Listing Teams"
      assert html =~ team.name
    end

    test "saves new team", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/teams")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Team")
               |> render_click()
               |> follow_redirect(conn, ~p"/admin/teams/new")

      assert render(form_live) =~ "New Team"

      assert form_live
             |> form("#team-form", team: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#team-form", team: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/admin/teams")

      html = render(index_live)
      assert html =~ "Team created successfully"
      assert html =~ "some name"
    end

    test "updates team in listing", %{conn: conn, team: team} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/teams")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#teams-#{team.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/admin/teams/#{team}/edit")

      assert render(form_live) =~ "Edit Team"

      assert form_live
             |> form("#team-form", team: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#team-form", team: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/admin/teams")

      html = render(index_live)
      assert html =~ "Team updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes team in listing", %{conn: conn, team: team} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/teams")

      assert index_live |> element("#teams-#{team.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#teams-#{team.id}")
    end
  end

  describe "Show" do
    setup [:create_team]

    test "displays team", %{conn: conn, team: team} do
      {:ok, _show_live, html} = live(conn, ~p"/admin/teams/#{team}")

      assert html =~ "Show Team"
      assert html =~ team.name
    end

    test "updates team and returns to show", %{conn: conn, team: team} do
      {:ok, show_live, _html} = live(conn, ~p"/admin/teams/#{team}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/admin/teams/#{team}/edit?return_to=show")

      assert render(form_live) =~ "Edit Team"

      assert form_live
             |> form("#team-form", team: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#team-form", team: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/admin/teams/#{team}")

      html = render(show_live)
      assert html =~ "Team updated successfully"
      assert html =~ "some updated name"
    end
  end
end

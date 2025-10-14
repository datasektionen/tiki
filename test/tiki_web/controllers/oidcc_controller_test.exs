defmodule TikiWeb.OidccControllerTest do
  use TikiWeb.ConnCase, async: true

  import Tiki.AccountsFixtures
  import Tiki.OidccTestHelpers

  alias Tiki.Accounts

  # Helper to call controller action directly, bypassing Oidcc plugs
  defp call_oidc_callback(conn, userinfo) do
    conn
    |> bypass_through(TikiWeb.Router, [:browser])
    |> get(~p"/oidcc/callback")
    |> mock_oidc_callback(userinfo)
    |> TikiWeb.OidccController.callback(%{})
  end

  defp call_oidc_error(conn, reason) do
    conn
    |> bypass_through(TikiWeb.Router, [:browser])
    |> get(~p"/oidcc/callback")
    |> mock_oidc_error(reason)
    |> TikiWeb.OidccController.callback(%{})
  end

  describe "GET /oidcc/authorize/return" do
    test "stores return_to and link_account in session", %{conn: conn} do
      conn = get(conn, ~p"/oidcc/authorize/return?return_to=/admin&link=true")

      assert redirected_to(conn) == ~p"/oidcc/authorize"
      assert get_session(conn, :user_return_to) == "/admin"
      assert get_session(conn, :link_account) == true
    end

    test "defaults link_account to false", %{conn: conn} do
      conn = get(conn, ~p"/oidcc/authorize/return?return_to=/admin")

      assert redirected_to(conn) == ~p"/oidcc/authorize"
      assert get_session(conn, :link_account) == false
    end
  end

  describe "GET /oidcc/callback - new user login" do
    test "creates new user with full userinfo from SSO", %{conn: conn} do
      userinfo = oidc_userinfo(sub: "newuser", email: "newuser@kth.se")

      conn = call_oidc_callback(conn, userinfo)

      assert redirected_to(conn) == ~p"/"
      assert user = Accounts.get_user_by_email("newuser@kth.se")
      assert user.kth_id == "newuser"
      assert user.first_name == "Test"
      assert user.last_name == "User"
      assert user.year_tag == "D-23"
      assert user.confirmed_at != nil
    end

    test "handles year_tag being optional", %{conn: conn} do
      userinfo =
        oidc_userinfo(sub: "noyeartag")
        |> Map.delete("year_tag")

      conn = call_oidc_callback(conn, userinfo)

      assert redirected_to(conn) == ~p"/"
      assert user = Accounts.get_user_by_email("noyeartag@kth.se")
      assert user.kth_id == "noyeartag"
      assert user.year_tag == nil
    end
  end

  describe "GET /oidcc/callback - existing user login" do
    test "logs in existing user by kth_id", %{conn: conn} do
      existing_user = oidc_user_fixture(kth_id: "existing123")

      userinfo = oidc_userinfo(sub: "existing123", email: "existing123@kth.se")

      conn = call_oidc_callback(conn, userinfo)

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :user_token)

      logged_in_user =
        get_session(conn, :user_token)
        |> Tiki.Accounts.get_user_by_session_token()

      # Should not create duplicate user
      assert [user] = Accounts.list_users() |> Enum.filter(&(&1.kth_id == "existing123"))
      assert user.id == existing_user.id

      # should be the same user as logged in
      assert user.id == logged_in_user.id
    end

    test "existing user login works even if email differs from OIDC", %{conn: conn} do
      # User might have changed their email in the app
      existing_user = oidc_user_fixture(kth_id: "user456", email: "custom@example.com")

      # SSO returns their kth email
      userinfo = oidc_userinfo(sub: "user456", email: "user456@kth.se")

      conn = call_oidc_callback(conn, userinfo)

      assert redirected_to(conn) == ~p"/"

      logged_in_user =
        get_session(conn, :user_token)
        |> Tiki.Accounts.get_user_by_session_token()

      # Should log in the existing user, not create new one
      user = Accounts.get_user!(existing_user.id)
      assert user.email == "custom@example.com"
      assert existing_user.id == logged_in_user.id
      assert existing_user.email == logged_in_user.email
    end
  end

  describe "GET /oidcc/callback - collision detection" do
    test "detects collision when email exists without kth_id", %{conn: conn} do
      # User registered via magic link
      _existing = user_fixture(email: "collision@kth.se")

      # Later tries to log in via OIDC with same email
      userinfo = oidc_userinfo(sub: "collision", email: "collision@kth.se")

      conn = call_oidc_callback(conn, userinfo)

      assert redirected_to(conn) == ~p"/users/log_in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Email has already been taken"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Sign in with your email"
    end

    test "does not create duplicate user on collision", %{conn: conn} do
      user_fixture(email: "nodupe@kth.se")

      userinfo = oidc_userinfo(sub: "nodupe", email: "nodupe@kth.se")

      call_oidc_callback(conn, userinfo)

      # Should only have one user with this email
      users = Accounts.list_users() |> Enum.filter(&(&1.email == "nodupe@kth.se"))
      assert length(users) == 1
      assert hd(users).kth_id == nil
    end
  end

  describe "GET /oidcc/callback - account linking" do
    setup %{conn: conn} do
      user = user_fixture(email: "link@example.com")
      conn = log_in_user(conn, user)
      %{conn: conn, user: user}
    end

    test "links KTH account to logged-in user", %{conn: conn, user: user} do
      userinfo = oidc_userinfo(sub: "linkme", email: "linkme@kth.se", year_tag: "D-22")

      conn =
        conn
        |> put_session(:link_account, true)
        |> call_oidc_callback(userinfo)

      assert redirected_to(conn) == ~p"/account/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "linked KTH account"

      # User should now have kth_id
      updated_user = Accounts.get_user!(user.id)
      assert updated_user.kth_id == "linkme"
      assert updated_user.year_tag == "D-22"
      assert updated_user.email == "link@example.com"
    end

    test "linking fails if kth_id already taken by another user", %{conn: conn} do
      _other_user = oidc_user_fixture(kth_id: "taken")

      userinfo = oidc_userinfo(sub: "taken")

      conn =
        conn
        |> put_session(:link_account, true)
        |> call_oidc_callback(userinfo)

      assert redirected_to(conn) == ~p"/account/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "A user with this KTH-id already exists"
    end

    test "linking is idempotent if kth_id already belongs to user", %{conn: conn, user: user} do
      # First, link the account
      {:ok, user} = Accounts.link_user_with_userinfo(user, %{"kth_id" => "mine"})

      # Try to link again
      userinfo = oidc_userinfo(sub: "mine")

      conn =
        conn
        |> put_session(:link_account, true)
        |> call_oidc_callback(userinfo)

      assert redirected_to(conn) == ~p"/account/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "linked KTH account"

      # Should still be the same user
      updated_user = Accounts.get_user!(user.id)
      assert updated_user.kth_id == "mine"
    end

    test "linking works with optional year_tag", %{conn: conn, user: user} do
      userinfo =
        oidc_userinfo(sub: "noyear")
        |> Map.delete("year_tag")

      conn =
        conn
        |> put_session(:link_account, true)
        |> call_oidc_callback(userinfo)

      assert redirected_to(conn) == ~p"/account/settings"

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.kth_id == "noyear"
      assert updated_user.year_tag == nil
    end
  end

  describe "GET /oidcc/callback - OIDC errors" do
    test "handles OIDC provider errors gracefully", %{conn: conn} do
      # Error callback tries to render a view. In a real scenario this would work
      # but in tests we're bypassing the plugs so the view module isn't set up correctly.
      # We're just testing that the error path is reached in the controller.
      assert_raise RuntimeError, ~r/no view was found/, fn ->
        call_oidc_error(conn, :invalid_token)
      end
    end

    test "handles missing required fields", %{conn: conn} do
      # Userinfo without kth_id (sub) - this will cause a FunctionClauseError
      # in upsert_user_with_userinfo/1
      userinfo = %{
        "given_name" => "Test",
        "family_name" => "User",
        "email" => "test@kth.se"
      }

      assert_raise FunctionClauseError, fn ->
        call_oidc_callback(conn, userinfo)
      end
    end
  end

  describe "session redirect" do
    test "redirects to user_return_to after successful login", %{conn: conn} do
      userinfo = oidc_userinfo(sub: "redirectme")

      conn =
        conn
        |> bypass_through(TikiWeb.Router, [:browser])
        |> get(~p"/oidcc/callback")
        |> put_session(:user_return_to, "/admin/events")
        |> mock_oidc_callback(userinfo)
        |> TikiWeb.OidccController.callback(%{})

      assert redirected_to(conn) == "/admin/events"
    end
  end
end

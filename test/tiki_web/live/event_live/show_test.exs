defmodule TikiWeb.EventLive.ShowTest do
  use TikiWeb.ConnCase

  import Tiki.EventsFixtures
  import Tiki.AccountsFixtures

  describe "Event Show page with localization" do
    test "displays event name and description in English by default", %{conn: conn} do
      event =
        event_fixture(%{
          name: "Test Event",
          name_sv: "Testevenemang",
          description: "This is a test event description",
          description_sv: "Detta är en testevenemangsbeskrivning",
          # Disable image to avoid LiveView phx-update issues
          image_url: nil
        })

      conn = get(conn, ~p"/events/#{event}")
      html = html_response(conn, 200)

      assert html =~ "Test Event"
      assert html =~ "This is a test event description"
      refute html =~ "testevenemangsbeskrivning"
    end

    test "displays event name and description in Swedish when locale is set to Swedish", %{
      conn: conn
    } do
      event =
        event_fixture(%{
          name: "Test Event",
          name_sv: "Testevenemang",
          description: "This is a test event description",
          description_sv: "Detta är en testevenemangsbeskrivning",
          image_url: nil
        })

      # Create a user with Swedish locale
      user = user_fixture(%{locale: "sv"})

      conn = log_in_user(conn, user)
      conn = get(conn, ~p"/events/#{event}")
      html = html_response(conn, 200)

      assert html =~ "Testevenemang"
      assert html =~ "Detta är en testevenemangsbeskrivning"
      refute html =~ "Test Event"
    end
  end
end

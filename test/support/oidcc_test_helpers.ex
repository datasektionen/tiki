defmodule Tiki.OidccTestHelpers do
  @moduledoc """
  Test helpers for mocking OIDC authentication flows.

  These helpers allow testing OIDC controller actions without requiring
  actual OAuth/OIDC provider interactions by directly injecting userinfo
  into the conn.private map that the Oidcc.Plug.AuthorizationCallback
  plug would normally populate.
  """

  import Plug.Conn

  @doc """
  Mocks a successful OIDC callback with the given userinfo.

  The userinfo map should contain the raw OIDC claims (like "sub", "given_name", etc.)
  before any key transformations. The controller will handle the mapping.

  ## Example

      userinfo = %{
        "sub" => "testuser",
        "given_name" => "Test",
        "family_name" => "User",
        "email" => "test@kth.se"
      }

      conn
      |> mock_oidc_callback(userinfo)
      |> get(~p"/oidcc/callback")
  """
  def mock_oidc_callback(conn, userinfo) when is_map(userinfo) do
    # Mock the success tuple that Oidcc.Plug.AuthorizationCallback would set
    put_private(conn, Oidcc.Plug.AuthorizationCallback, {:ok, {%{}, userinfo}})
  end

  @doc """
  Mocks a failed OIDC callback with the given error reason.

  ## Example

      conn
      |> mock_oidc_error(:invalid_token)
      |> get(~p"/oidcc/callback")
  """
  def mock_oidc_error(conn, reason) do
    put_private(conn, Oidcc.Plug.AuthorizationCallback, {:error, reason})
  end

  @doc """
  Creates a valid OIDC userinfo map with the given attributes.

  Default attributes are provided for convenience.

  ## Examples

      oidc_userinfo()
      #=> %{"sub" => "kthid123", "given_name" => "Test", ...}

      oidc_userinfo(sub: "myid", email: "custom@kth.se")
  """
  def oidc_userinfo(attrs \\ []) do
    kth_id = Keyword.get(attrs, :sub, "kthid#{System.unique_integer([:positive])}")

    defaults = %{
      "sub" => kth_id,
      "given_name" => Keyword.get(attrs, :given_name, "Test"),
      "family_name" => Keyword.get(attrs, :family_name, "User"),
      "email" => Keyword.get(attrs, :email, "#{kth_id}@kth.se"),
      "year_tag" => Keyword.get(attrs, :year_tag, "D-23")
    }

    # Allow overriding any field
    Enum.reduce(attrs, defaults, fn {key, value}, acc ->
      Map.put(acc, to_string(key), value)
    end)
  end
end

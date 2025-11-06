defmodule Tiki.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Tiki.Accounts` context.
  """

  import Ecto.Query
  alias Tiki.Accounts

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email()
    })
  end

  def unconfirmed_user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Accounts.register_user()

    user
  end

  def user_fixture(attrs \\ %{}) do
    user = unconfirmed_user_fixture(attrs)

    token =
      extract_user_token(fn url ->
        Accounts.deliver_login_instructions(user, url)
      end)

    {:ok, user, _expired_tokens} = Accounts.login_user_by_magic_link(token)

    user
  end

  def admin_user_fixture(attrs \\ %{}) do
    user_fixture(attrs)
    |> grant_permission("admin")
  end

  def grant_permission(%Accounts.User{} = user, permission) do
    :ok = Tiki.Support.PermissionServiceMock.grant_permission(user, permission)
    user
  end

  def extract_user_token(fun) do
    fun.(&"[TOKEN]#{&1}[TOKEN]")

    %{success: 1, failure: 0} = Oban.drain_queue(queue: :mail)

    [captured_email] = Swoosh.X.TestAssertions.flush_emails()

    [_, token | _] = String.split(captured_email.html_body, "[TOKEN]")

    token
  end

  def override_token_inserted_at(token, inserted_at) when is_binary(token) do
    Tiki.Repo.update_all(
      from(t in Accounts.UserToken,
        where: t.token == ^token
      ),
      set: [inserted_at: inserted_at]
    )
  end

  def generate_user_magic_link_token(user) do
    {encoded_token, user_token} = Accounts.UserToken.build_email_token(user, "login")
    Tiki.Repo.insert!(user_token)
    {encoded_token, user_token.token}
  end

  @doc """
  Creates a user via OIDC (with kth_id and confirmed).
  """
  def oidc_user_fixture(attrs \\ %{}) do
    kth_id = Keyword.get(attrs, :kth_id, "kthid#{System.unique_integer([:positive])}")
    email = Keyword.get(attrs, :email, "#{kth_id}@kth.se")

    userinfo = %{
      "kth_id" => kth_id,
      "email" => email,
      "first_name" => Keyword.get(attrs, :first_name, "Test"),
      "last_name" => Keyword.get(attrs, :last_name, "User"),
      "year_tag" => Keyword.get(attrs, :year_tag, "D-23")
    }

    {:ok, user} = Accounts.upsert_user_with_userinfo(userinfo)
    user
  end
end

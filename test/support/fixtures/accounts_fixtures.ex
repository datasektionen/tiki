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

  def extract_user_token(fun) do
    fun.(&"[TOKEN]#{&1}[TOKEN]")

    %{failure: 0} = Oban.drain_queue(queue: :email)

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
end

defmodule Tiki.Accounts.User do
  use Tiki.Schema
  import Ecto.Changeset

  schema "users" do
    field :first_name, :string
    field :last_name, :string
    field :full_name, :string
    field :email, :string

    field :kth_id, :string
    field :confirmed_at, :naive_datetime

    field :locale, :string, default: "en"

    has_many :memberships, Tiki.Teams.Membership

    timestamps()
  end

  def oidcc_changeset(user, attrs) do
    user
    |> cast(attrs, [:kth_id, :email, :first_name, :last_name])
    |> validate_required([:kth_id, :email])
    |> unique_constraint(:kth_id)
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, Tiki.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  @doc """
  A user changeset for registring a user.

  It requires the email to change otherwise an error is added.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :kth_id, :first_name, :last_name, :locale])
    |> validate_email(opts)
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :kth_id, :first_name, :last_name, :locale])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  A changeset for updating user preferences.
  """
  def user_data_changeset(user, attrs) do
    user
    |> cast(attrs, [:first_name, :last_name, :locale])
  end
end

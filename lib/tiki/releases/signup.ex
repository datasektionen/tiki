defmodule Tiki.Releases.Signup do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "release_signups" do
    field :position, :integer
    field :status, Ecto.Enum, values: [:pending, :accepted, :rejected]

    field :signed_up_at, :utc_datetime

    belongs_to :user, Tiki.Accounts.User
    belongs_to :release, Tiki.Releases.Release, type: :binary_id

    timestamps()
  end

  @doc false
  def changeset(signup, attrs) do
    signup
    |> cast(attrs, [:position, :status, :signed_up_at, :user_id, :release_id])
    |> validate_required([:position, :status, :signed_up_at, :user_id, :release_id])
  end
end

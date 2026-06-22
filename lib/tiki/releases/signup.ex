defmodule Tiki.Releases.Signup do
  use Tiki.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "release_signups" do
    field :status, Ecto.Enum,
      values: [:queued, :drawn, :seeded, :rejected, :lost],
      default: :queued

    field :decided_at, :utc_datetime

    belongs_to :decided_by, Tiki.Accounts.User
    belongs_to :user, Tiki.Accounts.User
    belongs_to :release, Tiki.Releases.Release, type: :binary_id

    # set at draw
    belongs_to :order, Tiki.Orders.Order, type: :binary_id

    # requested items
    has_many :items, Tiki.Releases.SignupItem

    timestamps()
  end

  @doc false
  def changeset(signup, attrs) do
    signup
    |> cast(attrs, [:status, :decided_at, :decided_by_id, :user_id, :release_id, :order_id])
    |> validate_required([:status, :user_id, :release_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:release_id)
    |> foreign_key_constraint(:order_id)
    |> foreign_key_constraint(:decided_by_id)
    |> unique_constraint(:unique_user,
      name: :release_signups_id_user_id_index,
      message: "only one signup per user per release"
    )
  end
end

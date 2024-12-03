defmodule Tiki.Teams.Membership do
  use Tiki.Schema
  import Ecto.Changeset

  schema "team_memberships" do
    field :role, Ecto.Enum, values: [:admin, :member]

    belongs_to :team, Tiki.Teams.Team
    belongs_to :user, Tiki.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role, :team_id, :user_id])
    |> validate_required([:role, :team_id, :user_id])
  end
end

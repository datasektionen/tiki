defmodule Tiki.Teams.Team do
  use Tiki.Schema
  import Ecto.Changeset

  schema "teams" do
    field :name, :string
    field :logo_url, :string
    field :description, :string
    field :contact_email, :string

    has_many :members, Tiki.Teams.Membership

    timestamps()
  end

  @doc false
  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name, :logo_url, :description, :contact_email])
    |> validate_required([:name, :contact_email])
  end
end

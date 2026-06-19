defmodule Tiki.Releases.SignupItem do
  use Tiki.Schema
  import Ecto.Changeset

  schema "release_signup_items" do
    field :quantity, :integer

    belongs_to :signup, Tiki.Releases.Signup, type: :binary_id
    belongs_to :ticket_type, Tiki.Tickets.TicketType, type: :binary_id

    timestamps()
  end

  @doc false
  def changeset(signup_item, attrs) do
    signup_item
    |> cast(attrs, [:quantity, :signup_id, :ticket_type_id])
    |> validate_required([:quantity, :signup_id, :ticket_type_id])
    |> validate_number(:quantity, greater_than: 0)
    |> foreign_key_constraint(:signup_id)
    |> foreign_key_constraint(:ticket_type_id)
  end
end

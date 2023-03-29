defmodule Tiki.Orders.Order do
  use Ecto.Schema
  import Ecto.Changeset

  schema "orders" do
    field :status, Ecto.Enum, values: [:pending, :paid, :cancelled]

    belongs_to :user, Tiki.Accounts.User
    has_many :tickets, Tiki.Orders.Ticket

    timestamps()
  end

  @doc false
  def changeset(order, attrs) do
    order
    |> cast(attrs, [:user_id])
    |> validate_required([])
  end
end

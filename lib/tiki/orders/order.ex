defmodule Tiki.Orders.Order do
  use Ecto.Schema
  import Ecto.Changeset

  schema "orders" do
    field :status, Ecto.Enum, values: [:pending, :paid, :cancelled], default: :pending

    belongs_to :user, Tiki.Accounts.User
    belongs_to :event, Tiki.Events.Event
    has_many :tickets, Tiki.Orders.Ticket

    timestamps()
  end

  @doc false
  def changeset(order, attrs) do
    order
    |> cast(attrs, [:user_id, :event_id, :status])
    |> validate_required([:status])
  end
end

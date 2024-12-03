defmodule Tiki.Orders.Order do
  use Tiki.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "orders" do
    field :status, Ecto.Enum, values: [:pending, :paid, :cancelled], default: :pending
    field :price, :integer

    belongs_to :user, Tiki.Accounts.User
    belongs_to :event, Tiki.Events.Event, type: :binary_id
    has_many :tickets, Tiki.Orders.Ticket

    has_one :stripe_checkout, Tiki.Checkouts.StripeCheckout
    has_one :swish_checkout, Tiki.Checkouts.SwishCheckout

    timestamps()
  end

  @doc false
  def changeset(order, attrs) do
    order
    |> cast(attrs, [:user_id, :event_id, :status, :price])
    |> validate_required([:event_id, :status, :price])
  end
end

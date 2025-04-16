defmodule Tiki.Orders.Order do
  use Tiki.Schema
  import Ecto.Changeset

  # Valid transitions for an order state machine
  @transitions %{
    pending: [:checkout, :cancelled],
    checkout: [:paid, :cancelled],
    paid: [],
    cancelled: []
  }

  @primary_key {:id, Ecto.UUID, autogenerate: false}
  @derive {Jason.Encoder,
           only: [
             :id,
             :status,
             :price,
             :user_id,
             :event_id,
             :tickets,
             :stripe_checkout,
             :swish_checkout
           ]}
  schema "orders" do
    field :status, Ecto.Enum, values: [:pending, :checkout, :paid, :cancelled], default: :pending
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

  def valid_transition?(from, to) do
    to in Map.get(@transitions, from, [])
  end
end

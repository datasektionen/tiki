defmodule Tiki.Checkouts.StripeCheckout do
  use Tiki.Schema
  import Ecto.Changeset

  schema "stripe_checkouts" do
    field :currency, :string
    field :payment_intent_id, :string
    field :payment_method_id, :string
    field :status, :string

    belongs_to :user, Tiki.Accounts.User
    belongs_to :order, Tiki.Orders.Order, type: :binary_id

    timestamps()
  end

  @doc false
  def changeset(stripe_checkout, attrs) do
    stripe_checkout
    |> cast(attrs, [
      :user_id,
      :order_id,
      :currency,
      :payment_intent_id,
      :payment_method_id,
      :status
    ])
    |> validate_required([:user_id, :order_id])
  end
end

defmodule Tiki.Checkouts.SwishCheckout do
  use Ecto.Schema
  import Ecto.Changeset

  schema "swish_checkouts" do
    field :swish_id, :string
    field :callback_identifier, :string
    field :token, :string

    field :status, :string

    belongs_to :user, Tiki.Accounts.User
    belongs_to :order, Tiki.Orders.Order, type: :binary_id

    timestamps()
  end

  @doc false
  def changeset(stripe_checkout, attrs) do
    stripe_checkout
    |> cast(attrs, [:user_id, :order_id, :swish_id, :callback_identifier, :token, :status])
    |> validate_inclusion(:status, ["PAID", "DECLINED", "ERROR", "CANCELLED"])
    |> validate_required([:user_id, :order_id, :swish_id, :callback_identifier, :token])
  end
end

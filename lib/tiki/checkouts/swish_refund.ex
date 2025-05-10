defmodule Tiki.Checkouts.SwishRefund do
  @moduledoc """
  Represents a refund of a Swish payment. We need to
  persist this because there is no way to get the refund
  ID from a swish payment request.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "swish_refunds" do
    field :refund_id, :string
    field :callback_identifier, :string
    field :status, :string

    belongs_to :swish_checkout, Tiki.Checkouts.SwishCheckout

    timestamps()
  end

  @doc false
  def changeset(refund, attrs) do
    refund
    |> cast(attrs, [:refund_id, :callback_identifier, :status, :swish_checkout_id])
    |> validate_required([:callback_identifier, :status])
    |> validate_inclusion(:status, ["CREATED", "DEBITED", "PAID", "ERROR"])
  end
end

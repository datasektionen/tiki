defmodule Tiki.Tickets.TicketType do
  use Tiki.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "ticket_types" do
    field :name, :string
    field :description, :string
    field :price, :integer
    field :promo_code, :string

    # TODO: implement release time and expire time
    field :release_time, Tiki.Types.DatetimeStockholm
    field :expire_time, Tiki.Types.DatetimeStockholm

    # ticket limits in orders
    field :purchase_limit, :integer
    field :purchasable, :boolean, default: true

    # For events with different time slots for different ticket types, eg. spex showings on multiple days
    field :start_time, Tiki.Types.DatetimeStockholm
    field :end_time, Tiki.Types.DatetimeStockholm

    belongs_to :ticket_batch, Tiki.Tickets.TicketBatch
    belongs_to :form, Tiki.Forms.Form

    has_many :tickets, Tiki.Orders.Ticket

    timestamps()
  end

  @doc false
  def changeset(ticket_types, attrs) do
    ticket_types
    |> cast(attrs, [
      :name,
      :description,
      :purchasable,
      :price,
      :release_time,
      :expire_time,
      :ticket_batch_id,
      :promo_code,
      :start_time,
      :end_time,
      :form_id,
      :purchase_limit
    ])
    |> validate_required([:name, :description, :purchasable, :price, :ticket_batch_id, :form_id])
    |> validate_number(:price, greater_than_or_equal_to: 0)
  end
end

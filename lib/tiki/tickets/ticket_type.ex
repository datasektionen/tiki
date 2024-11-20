defmodule Tiki.Tickets.TicketType do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "ticket_types" do
    field :description, :string
    field :expire_time, :utc_datetime
    field :name, :string
    field :price, :integer
    field :purchasable, :boolean, default: true
    field :release_time, :utc_datetime
    field :promo_code, :string

    belongs_to :ticket_batch, Tiki.Tickets.TicketBatch
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
      :promo_code
    ])
    |> validate_required([:name, :description, :purchasable, :price, :ticket_batch_id])
    |> validate_number(:price, greater_than_or_equal_to: 0)
  end
end

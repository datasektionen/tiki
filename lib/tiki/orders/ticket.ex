defmodule Tiki.Orders.Ticket do
  use Tiki.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "tickets" do
    field :price, :integer
    field :checked_in_at, :naive_datetime

    has_one :form_response, Tiki.Forms.Response

    belongs_to :ticket_type, Tiki.Tickets.TicketType, type: :binary_id
    belongs_to :order, Tiki.Orders.Order, type: :binary_id

    timestamps()
  end

  @doc false
  def changeset(ticket, attrs) do
    ticket
    |> cast(attrs, [:ticket_type_id, :order_id, :price, :checked_in_at])
    |> validate_required([:ticket_type_id, :order_id, :price])
  end
end

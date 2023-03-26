defmodule Tiki.Orders.Ticket do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tickets" do
    belongs_to :ticket_type, Tiki.Tickets.TicketType
    belongs_to :order, Tiki.Orders.Order

    timestamps()
  end

  @doc false
  def changeset(ticket, attrs) do
    ticket
    |> cast(attrs, [])
    |> validate_required([])
  end
end

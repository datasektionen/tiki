defmodule Tiki.Tickets.TicketBatch do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tiki.Tickets.TicketBatch

  schema "ticket_batches" do
    field :max_size, :integer
    field :min_size, :integer
    field :name, :string

    belongs_to :event, Tiki.Events.Event

    has_many :sub_batches, TicketBatch
    has_many :ticket_types, Tiki.Tickets.TicketType
    belongs_to :parent_batch, TicketBatch

    timestamps()
  end

  @doc false
  def changeset(ticket_batch, attrs) do
    ticket_batch
    |> cast(attrs, [:name, :min_size, :max_size, :event_id, :parent_batch_id])
    |> validate_required([:name])
  end
end

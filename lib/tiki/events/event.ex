defmodule Tiki.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  schema "events" do
    field :description, :string
    field :event_date, :utc_datetime
    field :name, :string
    field :location, :string
    field :image_url, :string

    has_many :ticket_batches, Tiki.Tickets.TicketBatch

    timestamps()
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:name, :description, :event_date, :location, :image_url])
    |> validate_required([:name, :description, :event_date])
  end
end

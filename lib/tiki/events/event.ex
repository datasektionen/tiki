defmodule Tiki.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "events" do
    field :description, :string
    field :event_date, :utc_datetime
    field :name, :string
    field :location, :string
    field :image_url, :string

    has_many :forms, Tiki.Forms.Form
    has_one :default_form, Tiki.Forms.Form

    has_many :ticket_batches, Tiki.Tickets.TicketBatch

    belongs_to :team, Tiki.Accounts.Team

    timestamps()
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:name, :description, :event_date, :location, :image_url, :team_id])
    |> validate_required([:name, :description, :event_date, :team_id])
    |> foreign_key_constraint(:team_id)
  end
end

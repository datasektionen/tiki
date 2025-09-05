defmodule Tiki.Events.Event do
  use Tiki.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "events" do
    field :description, :string
    field :description_sv, :string
    field :event_date, Tiki.Types.DatetimeStockholm
    field :name, :string
    field :name_sv, :string
    field :location, :string
    field :image_url, :string
    field :is_hidden, :boolean

    # maximum number of tickets that can be purchased in one order
    field :max_order_size, :integer

    has_many :forms, Tiki.Forms.Form
    belongs_to :default_form, Tiki.Forms.Form

    has_many :ticket_batches, Tiki.Tickets.TicketBatch
    has_many :orders, Tiki.Orders.Order

    belongs_to :team, Tiki.Teams.Team

    timestamps()
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :name,
      :name_sv,
      :description,
      :description_sv,
      :event_date,
      :location,
      :image_url,
      :is_hidden,
      :team_id,
      :default_form_id,
      :max_order_size
    ])
    |> validate_required([:name, :name_sv, :description, :description_sv, :event_date, :team_id])
    |> foreign_key_constraint(:team_id)
  end
end

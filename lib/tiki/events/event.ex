defmodule Tiki.Events.Event do
  use Tiki.Schema
  import Ecto.Changeset

  use Gettext, backend: TikiWeb.Gettext

  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "events" do
    field :description, :string
    field :description_sv, :string
    field :start_time, Tiki.Types.DatetimeStockholm
    field :end_time, Tiki.Types.DatetimeStockholm
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
      :start_time,
      :end_time,
      :location,
      :image_url,
      :is_hidden,
      :team_id,
      :default_form_id,
      :max_order_size
    ])
    |> validate_required([:name, :name_sv, :description, :description_sv, :start_time, :team_id])
    |> validate_greater_than(:end_time, :start_time)
    |> foreign_key_constraint(:team_id)
  end

  defp validate_greater_than(changeset, field, other_field) do
    validate_change(changeset, field, fn _, value ->
      if value && DateTime.compare(value, get_field(changeset, other_field)) != :gt do
        [{field, gettext("must be greater than %{other_field}", other_field: other_field)}]
      else
        []
      end
    end)
  end
end

defimpl Tiki.Localization, for: Tiki.Events.Event do
  def localize(event, "sv") do
    %Tiki.Events.Event{event | name: event.name_sv, description: event.description_sv}
  end

  def localize(event, "en"), do: event
end

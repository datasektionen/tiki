defmodule Tiki.Releases.Release do
  use Tiki.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "releases" do
    field :name, :string
    field :name_sv, :string

    field :opens_at, Tiki.Types.DatetimeStockholm
    field :signup_window_minutes, :integer
    field :purchase_window_minutes, :integer

    field :max_tickets_per_order, :integer

    field :seed, :integer
    field :drawn_at, :utc_datetime

    belongs_to :event, Tiki.Events.Event, type: :binary_id
    belongs_to :ticket_batch, Tiki.Tickets.TicketBatch

    has_many :signups, Tiki.Releases.Signup

    timestamps()
  end

  @doc false
  def changeset(release, attrs) do
    release
    |> cast(attrs, [
      :name,
      :name_sv,
      :opens_at,
      :signup_window_minutes,
      :purchase_window_minutes,
      :max_tickets_per_order,
      :seed,
      :drawn_at,
      :event_id,
      :ticket_batch_id
    ])
    |> validate_required([
      :name,
      :name_sv,
      :opens_at,
      :signup_window_minutes,
      :purchase_window_minutes,
      :event_id,
      :ticket_batch_id
    ])
    |> validate_number(:max_tickets_per_order, greater_than: 0)
    |> foreign_key_constraint(:event_id)
    |> foreign_key_constraint(:ticket_batch_id)
  end
end

defimpl Tiki.Localization, for: Tiki.Releases.Release do
  def localize(release, "sv") do
    %Tiki.Releases.Release{release | name: release.name_sv}
  end

  def localize(release, "en"), do: release
end

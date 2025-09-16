defmodule Tiki.Releases.Release do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "releases" do
    field :name, :string
    field :name_sv, :string
    field :starts_at, Tiki.Types.DatetimeStockholm
    field :ends_at, Tiki.Types.DatetimeStockholm

    belongs_to :event, Tiki.Events.Event, type: :binary_id
    belongs_to :ticket_batch, Tiki.Tickets.TicketBatch

    has_many :release_signups, Tiki.Releases.Signup

    timestamps()
  end

  @doc false
  def changeset(release, attrs) do
    release
    |> cast(attrs, [:name, :name_sv, :starts_at, :ends_at, :event_id, :ticket_batch_id])
    |> validate_required([:name, :name_sv, :starts_at, :ends_at, :event_id, :ticket_batch_id])
  end
end

defimpl Tiki.Localization, for: Tiki.Releases.Release do
  def localize(release, "sv") do
    %Tiki.Releases.Release{release | name: release.name_sv}
  end

  def localize(release, "en"), do: release
end

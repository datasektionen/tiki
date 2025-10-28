defmodule Tiki.Tickets.TicketBatch do
  use Tiki.Schema
  import Ecto.Changeset

  alias Tiki.Tickets.TicketBatch

  schema "ticket_batches" do
    field :max_size, :integer
    field :min_size, :integer
    field :name, :string

    belongs_to :event, Tiki.Events.Event, type: :binary_id

    has_many :sub_batches, TicketBatch, foreign_key: :parent_batch_id
    has_many :ticket_types, Tiki.Tickets.TicketType
    has_one :release, Tiki.Releases.Release

    belongs_to :parent_batch, TicketBatch

    timestamps()
  end

  @doc false
  def changeset(ticket_batch, attrs) do
    ticket_batch
    |> cast(attrs, [:name, :min_size, :max_size, :parent_batch_id])
    |> validate_number(:max_size, greater_than_or_equal_to: 0)
    |> validate_number(:min_size, greater_than_or_equal_to: 0)
    |> validate_required([:name, :event_id, :max_size])
    |> foreign_key_constraint(:event_id)
    |> validate_not_equal(:id, :parent_batch_id)
  end

  defp validate_not_equal(changeset, a, b, _opts \\ []) do
    a_val = fetch_field(changeset, a)
    b_val = fetch_field(changeset, b)

    case {a_val, b_val} do
      {{:data, nil}, _} -> changeset
      {_, {:data, nil}} -> changeset
      {{_, a}, {_, b}} when a == b -> add_error(changeset, a, "#{a} must not be equal to #{b}")
      _ -> changeset
    end
  end
end

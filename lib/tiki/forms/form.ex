defmodule Tiki.Forms.Form do
  use Tiki.Schema
  import Ecto.Changeset

  schema "forms" do
    field :name, :string
    field :description, :string
    field :description_sv, :string

    belongs_to :event, Tiki.Events.Event, type: :binary_id
    has_many :questions, Tiki.Forms.Question, on_replace: :delete
    has_many :responses, Tiki.Forms.Response, on_replace: :delete
    has_many :ticket_types, Tiki.Tickets.TicketType, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(form, attrs) do
    form
    |> cast(attrs, [:name, :description, :description_sv, :event_id])
    |> validate_required([:name, :description, :event_id])
    |> cast_assoc(:questions, sort_param: :questions_sort, drop_param: :questions_drop)
  end
end

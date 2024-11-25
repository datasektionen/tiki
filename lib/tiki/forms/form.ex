defmodule Tiki.Forms.Form do
  use Ecto.Schema
  import Ecto.Changeset

  schema "forms" do
    field :description, :string
    field :name, :string

    belongs_to :event, Tiki.Events.Event
    has_many :questions, Tiki.Forms.Question, on_replace: :delete
    has_many :responses, Tiki.Forms.Response, on_replace: :delete
    has_many :ticket_types, Tiki.Tickets.TicketType, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(form, attrs) do
    form
    |> cast(attrs, [:name, :description])
    |> validate_required([:name, :description])
    |> cast_assoc(:questions, sort_param: :questions_sort, drop_param: :questions_drop)
  end
end

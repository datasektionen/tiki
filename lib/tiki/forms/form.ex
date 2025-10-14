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
    |> cast(attrs, [:name, :description, :description_sv])
    |> validate_required([:name, :description, :event_id])
    |> foreign_key_constraint(:event_id)
    |> cast_assoc(:questions, sort_param: :questions_sort, drop_param: :questions_drop)
  end
end

defimpl Tiki.Localization, for: Tiki.Forms.Form do
  def localize(form, "sv") do
    form = %Tiki.Forms.Form{form | description: form.description_sv}

    case form.questions do
      questions when is_list(questions) ->
        %Tiki.Forms.Form{form | questions: Tiki.Localizer.localize(questions)}

      _ ->
        form
    end
  end

  def localize(form, "en"), do: form
end

defmodule Tiki.Forms.Question do
  use Tiki.Schema
  import Ecto.Changeset

  schema "form_questions" do
    field :description, :string
    field :name, :string
    field :required, :boolean, default: false

    field :type, Ecto.Enum,
      values: [:text, :text_area, :select, :multi_select, :email, :attendee_name]

    field :options, {:array, :string}

    belongs_to :form, Tiki.Forms.Form

    timestamps()
  end

  @doc false
  def changeset(form_question, attrs) do
    form_question
    |> cast(attrs, [:name, :type, :description, :required, :form_id, :options])
    |> validate_required([:name, :type])
  end
end

defmodule Tiki.Forms.Question do
  use Tiki.Schema
  import Ecto.Changeset

  use Gettext, backend: TikiWeb.Gettext

  schema "form_questions" do
    field :name, :string
    field :name_sv, :string
    field :description, :string
    field :description_sv, :string

    field :required, :boolean, default: false

    field :type, Ecto.Enum,
      values: [:text, :text_area, :select, :multi_select, :email, :attendee_name]

    field :options, {:array, :string}
    field :options_sv, {:array, :string}

    belongs_to :form, Tiki.Forms.Form

    timestamps()
  end

  @doc false
  def changeset(form_question, attrs) do
    form_question
    |> cast(attrs, [
      :name,
      :name_sv,
      :type,
      :description,
      :description_sv,
      :required,
      :form_id,
      :options,
      :options_sv
    ])
    |> validate_required([:name, :name_sv, :type])
    |> validate_equal_num_options()
  end

  defp validate_equal_num_options(changeset) do
    options = get_field(changeset, :options)
    options_sv = get_field(changeset, :options_sv)
    type = get_field(changeset, :type)

    case {type, options, options_sv} do
      {_, nil, nil} ->
        changeset

      {_, _, nil} ->
        add_error(changeset, :options, gettext("Number of options must be equal"))
        |> add_error(:options_sv, gettext("Number of options must be equal"))

      {_, nil, _} ->
        add_error(changeset, :options, gettext("Number of options must be equal"))
        |> add_error(:options_sv, gettext("Number of options must be equal"))

      {type, options, options_sv} when type in [:select, :multi_select] ->
        if length(options) != length(options_sv) do
          add_error(changeset, :options, gettext("Number of options must be equal"))
          |> add_error(:options_sv, gettext("Number of options must be equal"))
        else
          changeset
        end

      _ ->
        changeset
    end
  end
end

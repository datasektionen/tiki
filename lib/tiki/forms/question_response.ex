defmodule Tiki.Forms.QuestionResponse do
  use Tiki.Schema
  import Ecto.Changeset

  schema "form_question_responses" do
    field :answer, :string
    field :multi_answer, {:array, :string}

    belongs_to :response, Tiki.Forms.Response
    belongs_to :question, Tiki.Forms.Question

    timestamps()
  end

  @doc false
  def changeset(question_response, attrs) do
    question_response
    |> cast(attrs, [:answer, :multi_answer, :response_id, :question_id])
    |> validate_required([:question_id, :response_id])
    |> validate_one_required([:answer, :multi_answer])
  end

  defp validate_one_required(changeset, fields) do
    field_values = Enum.map(fields, fn field -> get_field(changeset, field) end)
    field_names = Enum.join(fields, ", ")

    case Enum.count(Enum.reject(field_values, &is_nil/1)) do
      0 -> add_error(changeset, hd(fields), "one field must be present among: #{field_names}")
      1 -> changeset
      _ -> add_error(changeset, hd(fields), "only one field can be present among: #{field_names}")
    end
  end

  @doc """
  Returns a changeset from a question answer.

  ## Examples

      iex> from_answer(%Tiki.Forms.Response{}, {:2, "Cool answer"})
      %Ecto.Changeset{data: %Tiki.Forms.QuestionResponse{answer: "Cool answer"}}

      iex> from_answer(%Tiki.Forms.Response{}, {:2, ["Cool answer", "Another answer"]})
      %Ecto.Changeset{data: %Tiki.Forms.QuestionResponse{multi_answer: ["Cool answer", "Another answer"]}}
  """
  def from_answer(response, question_id, answer) when is_list(answer) do
    changeset(%__MODULE__{}, %{
      question_id: question_id,
      response_id: response.id,
      multi_answer: answer
    })
  end

  def from_answer(response, question_id, answer) do
    changeset(%__MODULE__{}, %{
      question_id: question_id,
      response_id: response.id,
      answer: answer
    })
  end
end

defimpl Phoenix.HTML.Safe, for: Tiki.Forms.QuestionResponse do
  def to_iodata(question_response) do
    case {question_response.answer, question_response.multi_answer} do
      {nil, nil} -> ""
      {nil, multi_answer} -> Enum.join(multi_answer, ", ") |> Phoenix.HTML.Engine.html_escape()
      {answer, nil} -> Phoenix.HTML.Engine.html_escape(answer)
    end
  end
end

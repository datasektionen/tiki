defmodule Tiki.Forms.Response do
  use Ecto.Schema
  import Ecto.Changeset

  schema "form_responses" do
    belongs_to :form, Tiki.Forms.Form
    belongs_to :ticket, Tiki.Tickets.Ticket, type: :binary_id

    has_many :question_responses, Tiki.Forms.QuestionResponse

    timestamps()
  end

  @doc false
  def changeset(response, attrs) do
    response
    |> cast(attrs, [:form_id, :ticket_id, :question_id])
    |> validate_required([])
  end
end

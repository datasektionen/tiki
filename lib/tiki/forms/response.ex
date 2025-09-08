defmodule Tiki.Forms.Response do
  use Tiki.Schema
  import Ecto.Changeset

  schema "form_responses" do
    belongs_to :form, Tiki.Forms.Form
    belongs_to :ticket, Tiki.Orders.Ticket, type: :binary_id

    has_many :question_responses, Tiki.Forms.QuestionResponse

    timestamps()
  end

  @doc false
  def changeset(response, attrs) do
    response
    |> cast(attrs, [:form_id, :ticket_id])
    |> validate_required([:form_id, :ticket_id])
  end
end

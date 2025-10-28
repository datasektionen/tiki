defmodule Tiki.FormsFixtures do
  def form_fixture(attrs \\ %{}) do
    event = Tiki.EventsFixtures.event_fixture()

    {:ok, form} =
      attrs
      |> Enum.into(%{
        description: "some description",
        description_sv: "någon beskrivning",
        name: "some name"
      })
      |> then(&Tiki.Forms.create_form(event.id, &1))

    form
  end

  def response_fixture(attrs \\ %{}) do
    form = form_fixture(Map.get(attrs, :form, %{}))
    ticket = Tiki.OrdersFixtures.ticket_fixture()

    question_ids = Enum.map(form.questions, & &1.id)

    response = %Tiki.Forms.Response{
      question_responses:
        Enum.map(question_ids, fn id ->
          %{question_id: id, answer: "answer #{id}"}
        end)
    }

    {:ok, response} = Tiki.Forms.submit_response(form.id, ticket.id, response)

    response
  end
end

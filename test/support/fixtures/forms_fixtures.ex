defmodule Tiki.FormsFixtures do
  def form_fixture(attrs \\ %{}) do
    event = Tiki.EventsFixtures.event_fixture()

    {:ok, form} =
      attrs
      |> Enum.into(%{
        description: "some description",
        name: "some name",
        event_id: event.id
      })
      |> Tiki.Forms.create_form()

    form
  end

  def response_fixture(attrs \\ %{}) do
    form = form_fixture(Map.get(attrs, :form, %{}))

    question_ids = Enum.map(form.questions, & &1.id)

    response = %Tiki.Forms.Response{
      form_id: form.id,
      question_responses:
        Enum.map(question_ids, fn id ->
          %{question_id: id, answer: "answer #{id}"}
        end)
    }

    {:ok, response} = Tiki.Forms.submit_response(response)

    response
  end
end

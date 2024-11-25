defmodule Tiki.FormsTest do
  use Tiki.DataCase

  describe "form" do
    import Tiki.FormsFixtures

    test "create_form/1 with valid data creates a form" do
      assert {:ok, %Tiki.Forms.Form{}} =
               Tiki.Forms.create_form(%{description: "some description", name: "some name"})
    end

    test "create_form/1 with questions creates a form with questions" do
      attrs = %{
        description: "some description",
        name: "some name",
        questions: [
          %{
            name: "Quesiton name",
            type: "text"
          }
        ]
      }

      assert {:ok, %Tiki.Forms.Form{questions: [%Tiki.Forms.Question{type: :text}]}} =
               Tiki.Forms.create_form(attrs)
    end

    test "get_form_changeset!/2 with valid data returns a valid changeset" do
      attrs = %{
        questions: [
          %{
            name: "Quesiton name",
            type: "text",
            required: true
          },
          %{
            name: "Quesiton 2",
            type: "select",
            options: ["option 1", "option 2"]
          }
        ]
      }

      form = form_fixture(attrs)
      question_ids = Enum.map(form.questions, & &1.id)

      response = %Tiki.Forms.Response{
        question_responses: [
          %{question_id: Enum.at(question_ids, 0), answer: "Answer 1"},
          %{question_id: Enum.at(question_ids, 1), answer: "option 1"}
        ]
      }

      assert %Ecto.Changeset{valid?: true} = Tiki.Forms.get_form_changeset!(form.id, response)
    end

    # TODO: test get_form_changeset!/2 with different types of invalid data

    test "submit_response/2 with valid data submits the form" do
      attrs = %{
        questions: [
          %{
            name: "Quesiton name",
            type: "text",
            required: true
          }
        ]
      }

      form = form_fixture(attrs)
      question_ids = Enum.map(form.questions, & &1.id)

      response = %Tiki.Forms.Response{
        form_id: form.id,
        question_responses: [
          %{question_id: Enum.at(question_ids, 0), answer: "Answer 1"}
        ]
      }

      assert {:ok, %Tiki.Forms.Response{} = response} =
               Tiki.Forms.submit_response(response)

      assert Enum.count(response.question_responses) == 1
      assert Enum.at(response.question_responses, 0).answer == "Answer 1"
    end

    # TODO: test submit_form/2 with different types of invalid data

    # TODO: test update_form_response/3
  end
end

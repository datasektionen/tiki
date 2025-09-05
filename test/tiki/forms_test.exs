defmodule Tiki.FormsTest do
  use Tiki.DataCase

  describe "form" do
    import Tiki.FormsFixtures

    test "list_forms_for_event/1 returns all forms" do
      form = form_fixture()
      assert form in Tiki.Forms.list_forms_for_event(form.event_id)
    end

    test "create_form/1 with valid data creates a form" do
      event = Tiki.EventsFixtures.event_fixture()

      assert {:ok, %Tiki.Forms.Form{}} =
               Tiki.Forms.create_form(%{
                 description: "some description",
                 name: "some name",
                 event_id: event.id
               })
    end

    test "create_form/1 with questions creates a form with questions" do
      event = Tiki.EventsFixtures.event_fixture()

      attrs = %{
        description: "some description",
        name: "some name",
        event_id: event.id,
        questions: [
          %{
            name: "Quesiton name",
            name_sv: "Frågans namn",
            type: "text"
          }
        ]
      }

      assert {:ok, %Tiki.Forms.Form{questions: [%Tiki.Forms.Question{type: :text}]}} =
               Tiki.Forms.create_form(attrs)
    end

    test "create_form/1 with invalid data returns an invalid changeset" do
      assert {:error, %Ecto.Changeset{valid?: false}} = Tiki.Forms.create_form()
    end

    test "create_form/1 with different number of options in English and Swedish returns an invalid changeset" do
      event = Tiki.EventsFixtures.event_fixture()

      attrs = %{
        description: "some description",
        name: "some name",
        event_id: event.id,
        questions: [
          %{
            name: "Quesiton name",
            name_sv: "Frågans namn",
            type: "select",
            options: ["option 1", "option 2"],
            options_sv: ["alternativ 1"]
          }
        ]
      }

      assert {:error, %Ecto.Changeset{valid?: false}} =
               Tiki.Forms.create_form(attrs)
    end

    test "update_form/2 with valid data updates the form" do
      form = form_fixture()

      assert {:ok, %Tiki.Forms.Form{} = form} =
               Tiki.Forms.update_form(form, %{name: "New name"})

      assert form.name == "New name"
    end

    test "delete_form/1 deletes the form" do
      form = form_fixture()
      assert {:ok, %Tiki.Forms.Form{}} = Tiki.Forms.delete_form(form)
      assert_raise Ecto.NoResultsError, fn -> Tiki.Forms.get_form!(form.id) end
    end

    test "change_form/1 returns a form changeset" do
      form = form_fixture()
      assert %Ecto.Changeset{} = Tiki.Forms.change_form(form)
    end

    test "get_form_changeset!/2 with valid data returns a valid changeset" do
      attrs = %{
        questions: [
          %{
            name: "Quesiton name",
            name_sv: "Frågans namn",
            type: "text",
            required: true
          },
          %{
            name: "Quesiton 2",
            name_sv: "Fråga 2",
            type: "select",
            options: ["option 1", "option 2"],
            options_sv: ["alternativ 1", "alternativ 2"]
          },
          %{
            name: "Quesiton 3",
            name_sv: "Fråga 3",
            type: "multi_select",
            required: true,
            options: ["alternative 1", "alternative 2"],
            options_sv: ["alternativ 1", "alternativ 2"]
          }
        ]
      }

      form = form_fixture(attrs)
      question_ids = Enum.map(form.questions, & &1.id)

      response = %Tiki.Forms.Response{
        question_responses: [
          %{question_id: Enum.at(question_ids, 0), answer: "Answer 1"},
          %{question_id: Enum.at(question_ids, 1), answer: "option 1"},
          %{
            question_id: Enum.at(question_ids, 2),
            answer: ["alternative 1", "alternative 2"]
          }
        ]
      }

      assert %Ecto.Changeset{valid?: true} = Tiki.Forms.get_form_changeset!(form.id, response)
    end

    test "get_form_changeset!/2 with valid bilingual data returns a valid changeset" do
      attrs = %{
        questions: [
          %{
            name: "Quesiton 2",
            name_sv: "Fråga 2",
            type: "select",
            options: ["option 1", "option 2"],
            options_sv: ["alternativ 1", "alternativ 2"]
          },
          %{
            name: "Quesiton 3",
            name_sv: "Fråga 3",
            type: "multi_select",
            required: true,
            options: ["alternative 1", "alternative 2"],
            options_sv: ["svarsalternativ 1", "svarsalternativ 2"]
          }
        ]
      }

      form = form_fixture(attrs)
      question_ids = Enum.map(form.questions, & &1.id)

      response = %Tiki.Forms.Response{
        question_responses: [
          %{question_id: Enum.at(question_ids, 0), answer: "alternativ 1"},
          %{
            question_id: Enum.at(question_ids, 1),
            answer: ["svarsalternativ 1", "svarsalternativ 2"]
          }
        ]
      }

      assert %Ecto.Changeset{valid?: true} = Tiki.Forms.get_form_changeset!(form.id, response)
    end

    test "get_form_changeset!/2 without required data returns an invalid changeset" do
      attrs = %{
        questions: [
          %{
            name: "Quesiton 3",
            name_sv: "Fråga 3",
            type: "multi_select",
            required: true,
            options: ["option 1", "option 2"],
            options_sv: ["alternativ 1", "alternativ 2"]
          }
        ]
      }

      form = form_fixture(attrs)

      response = %Tiki.Forms.Response{
        question_responses: []
      }

      assert %Ecto.Changeset{valid?: false} =
               changeset = Tiki.Forms.get_form_changeset!(form.id, response)

      assert Enum.count(changeset.errors) == 1

      assert [{"can't be blank", [validation: :required]}] ==
               Enum.map(changeset.errors, fn {_, value} -> value end)
    end

    test "get_form_changeset!/2 with invalid option returns an invalid changeset" do
      attrs = %{
        questions: [
          %{
            name: "Quesiton 3",
            name_sv: "Fråga 3",
            type: "select",
            options: ["option 1", "option 2"],
            options_sv: ["alternativ 1", "alternativ 2"]
          }
        ]
      }

      form = form_fixture(attrs)
      question_ids = Enum.map(form.questions, & &1.id)

      response = %Tiki.Forms.Response{
        question_responses: [
          %{question_id: Enum.at(question_ids, 0), answer: "Not a valid option"}
        ]
      }

      assert %Ecto.Changeset{valid?: false} =
               changeset = Tiki.Forms.get_form_changeset!(form.id, response)

      assert Enum.count(changeset.errors) == 1

      assert [{"value must be an available option", _}] =
               Enum.map(changeset.errors, fn {_, value} -> value end)
    end

    test "get_form_changeset!/2 with no selected multi_select option returns an invalid changeset" do
      attrs = %{
        questions: [
          %{
            name: "Quesiton 3",
            name_sv: "Fråga 3",
            type: "multi_select",
            options: ["option 1", "option 2"],
            options_sv: ["alternativ 1", "alternativ 2"],
            required: true
          }
        ]
      }

      form = form_fixture(attrs)
      question_ids = Enum.map(form.questions, & &1.id)

      response = %Tiki.Forms.Response{
        question_responses: [
          %{question_id: Enum.at(question_ids, 0), answer: ["option 1", "not an option"]}
        ]
      }

      assert %Ecto.Changeset{valid?: false} =
               changeset = Tiki.Forms.get_form_changeset!(form.id, response)

      assert Enum.count(changeset.errors) == 1

      assert [{"all values must be available options", _}] =
               Enum.map(changeset.errors, fn {_, value} -> value end)
    end

    test "get_form_changeset!/2 with invalid selected multi_select option returns an invalid changeset" do
      attrs = %{
        questions: [
          %{
            name: "Quesiton 3",
            name_sv: "Fråga 3",
            type: "multi_select",
            options: ["option 1", "option 2"],
            options_sv: ["alternativ 1", "alternativ 2"],
            required: true
          }
        ]
      }

      form = form_fixture(attrs)

      response = %Tiki.Forms.Response{
        question_responses: []
      }

      assert %Ecto.Changeset{valid?: false} =
               changeset = Tiki.Forms.get_form_changeset!(form.id, response)

      assert Enum.count(changeset.errors) == 1

      assert [{"can't be blank", _}] =
               Enum.map(changeset.errors, fn {_, value} -> value end)
    end

    test "submit_response/3 with valid data submits the form" do
      attrs = %{
        questions: [
          %{
            name: "Quesiton name",
            name_sv: "Frågans namn",
            type: "text",
            required: true
          },
          %{
            name: "Quesiton name 2",
            name_sv: "Frågans namn 2",
            type: "multi_select",
            options: ["option 1", "option 2"],
            options_sv: ["alternativ 1", "alternativ 2"]
          }
        ]
      }

      form = form_fixture(attrs)
      ticket = Tiki.OrdersFixtures.ticket_fixture()
      question_ids = Enum.map(form.questions, & &1.id)

      response = %Tiki.Forms.Response{
        form_id: form.id,
        question_responses: [
          %{question_id: Enum.at(question_ids, 0), answer: "Answer 1"},
          %{question_id: Enum.at(question_ids, 1), answer: ["option 1", "option 2"]}
        ]
      }

      assert {:ok, %Tiki.Forms.Response{} = response} =
               Tiki.Forms.submit_response(form.id, ticket.id, response)

      assert Enum.count(response.question_responses) == 2
      assert Enum.at(response.question_responses, 0).answer == "Answer 1"
      assert Enum.at(response.question_responses, 1).multi_answer == ["option 1", "option 2"]
      assert response.ticket_id == ticket.id
      assert response.form_id == form.id
    end

    test "submit_response/3 with invalid data returns a changeset" do
      attrs = %{
        questions: [
          %{
            name: "Quesiton name",
            name_sv: "Frågans namn",
            type: "text",
            required: true
          }
        ]
      }

      form = form_fixture(attrs)
      ticket = Tiki.OrdersFixtures.ticket_fixture()

      response = %{question_responses: []}

      assert {:error, %Ecto.Changeset{valid?: false}} =
               Tiki.Forms.submit_response(form.id, ticket.id, response)
    end

    test "submit_response/3 with invalid form returns a changeset" do
      response = %{
        question_responses: []
      }

      assert {:error, "form not found"} = Tiki.Forms.submit_response(123_123, 1231, response)
    end

    test "update_form_response/3 with valid data updates the form response" do
      attrs = %{
        form: %{
          questions: [
            %{
              name: "Quesiton name",
              name_sv: "Frågans namn",
              type: "text",
              required: true
            }
          ]
        }
      }

      response = response_fixture(attrs)
      form = Tiki.Forms.get_form!(response.form_id) |> Tiki.Repo.preload(:questions)
      question_ids = Enum.map(form.questions, & &1.id)

      response_attrs = %Tiki.Forms.Response{
        form_id: form.id,
        question_responses: [
          %{question_id: Enum.at(question_ids, 0), answer: "Coolest answer ever"}
        ]
      }

      assert {:ok, %Tiki.Forms.Response{} = response} =
               Tiki.Forms.update_form_response(response, response_attrs)

      assert Enum.count(response.question_responses) == 1
      assert Enum.at(response.question_responses, 0).answer == "Coolest answer ever"
    end

    test "update_form_response/3 with invalid data returns an invalid changeset" do
      attrs = %{
        form: %{
          questions: [
            %{
              name: "Quesiton name",
              name_sv: "Frågans namn",
              type: "text",
              required: true
            }
          ]
        }
      }

      response = response_fixture(attrs)
      form = Tiki.Forms.get_form!(response.form_id)

      response_attrs = %Tiki.Forms.Response{
        form_id: form.id,
        question_responses: []
      }

      assert {:error, %Ecto.Changeset{valid?: false}} =
               Tiki.Forms.update_form_response(response, response_attrs)
    end

    test "Tiki.Forms.QuestionResponse implements Phoenix.HTML.Safe" do
      assert "Answer 1" ==
               Phoenix.HTML.Safe.to_iodata(%Tiki.Forms.QuestionResponse{
                 question_id: 1,
                 answer: "Answer 1"
               })

      assert "Answer 1, Answer 2" ==
               Phoenix.HTML.Safe.to_iodata(%Tiki.Forms.QuestionResponse{
                 question_id: 1,
                 multi_answer: ["Answer 1", "Answer 2"]
               })

      assert "" ==
               Phoenix.HTML.Safe.to_iodata(%Tiki.Forms.QuestionResponse{
                 question_id: 1
               })
    end
  end
end

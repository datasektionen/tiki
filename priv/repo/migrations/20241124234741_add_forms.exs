defmodule Tiki.Repo.Migrations.AddForms do
  use Ecto.Migration

  def change do
    create table(:forms) do
      add :description, :string
      add :name, :string
      add :event_id, references(:events, type: :binary_id)

      timestamps()
    end

    create index(:forms, [:event_id])

    create table(:form_questions) do
      add :description, :string
      add :name, :string
      add :required, :boolean, default: false
      add :type, :string
      add :options, {:array, :string}
      add :form_id, references(:forms)

      timestamps()
    end

    create index(:form_questions, [:form_id])

    create table(:form_responses) do
      add :form_id, references(:forms)
      add :ticket_id, references(:tickets, type: :binary_id)

      timestamps()
    end

    create index(:form_responses, [:form_id])
    create index(:form_responses, [:ticket_id])

    create table(:form_question_responses) do
      add :answer, :string
      add :multi_answer, {:array, :string}
      add :response_id, references(:form_responses)
      add :question_id, references(:form_questions)

      timestamps()
    end

    create index(:form_question_responses, [:response_id])
    create index(:form_question_responses, [:question_id])

    alter table(:ticket_types) do
      add :form_id, references(:forms)
    end

    create index(:ticket_types, [:form_id])

    alter table(:tickets) do
      add :response_id, references(:form_responses)
    end

    create index(:tickets, [:response_id])
  end
end

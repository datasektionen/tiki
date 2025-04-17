defmodule Tiki.Repo.Migrations.AllowEventDeletion do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE forms DROP CONSTRAINT forms_event_id_fkey"
    execute "ALTER TABLE form_questions DROP CONSTRAINT form_questions_form_id_fkey"
    execute "ALTER TABLE form_responses DROP CONSTRAINT form_responses_form_id_fkey"

    execute "ALTER TABLE form_question_responses DROP CONSTRAINT form_question_responses_response_id_fkey"

    execute "ALTER TABLE form_question_responses DROP CONSTRAINT form_question_responses_question_id_fkey"

    execute "ALTER TABLE ticket_batches DROP CONSTRAINT ticket_batches_event_id_fkey"

    alter table(:forms) do
      modify :event_id, references(:events, type: :binary_id, on_delete: :delete_all)
    end

    alter table(:form_questions) do
      modify :form_id, references(:forms, on_delete: :delete_all)
    end

    alter table(:form_responses) do
      modify :form_id, references(:forms, on_delete: :delete_all)
    end

    alter table(:form_question_responses) do
      modify :response_id, references(:form_responses, on_delete: :delete_all)
      modify :question_id, references(:form_questions, on_delete: :delete_all)
    end

    alter table(:ticket_batches) do
      modify :event_id, references(:events, type: :binary_id, on_delete: :nilify_all)
    end
  end

  def down do
    execute "ALTER TABLE forms DROP CONSTRAINT forms_event_id_fkey"
    execute "ALTER TABLE form_questions DROP CONSTRAINT form_questions_form_id_fkey"
    execute "ALTER TABLE form_responses DROP CONSTRAINT form_responses_form_id_fkey"
    execute "ALTER TABLE ticket_batches DROP CONSTRAINT ticket_batches_event_id_fkey"

    execute "ALTER TABLE form_question_responses DROP CONSTRAINT form_question_responses_response_id_fkey"

    execute "ALTER TABLE form_question_responses DROP CONSTRAINT form_question_responses_question_id_fkey"

    alter table(:forms) do
      modify :event_id, references(:events, type: :binary_id)
    end

    alter table(:form_questions) do
      modify :form_id, references(:forms)
    end

    alter table(:form_responses) do
      modify :form_id, references(:forms)
    end

    alter table(:form_question_responses) do
      modify :response_id, references(:form_responses)
      modify :question_id, references(:form_questions)
    end

    alter table(:ticket_batches) do
      modify :event_id, references(:events, type: :binary_id, on_delete: :nothing)
    end
  end
end

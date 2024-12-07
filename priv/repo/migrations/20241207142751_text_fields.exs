defmodule Tiki.Repo.Migrations.TextFields do
  use Ecto.Migration

  def up do
    alter table(:events) do
      modify :description, :text
      modify :location, :text
      modify :image_url, :text
    end

    alter table(:forms) do
      modify :description, :text
    end

    alter table(:form_questions) do
      modify :description, :text
      modify :options, {:array, :text}
    end

    alter table(:form_question_responses) do
      modify :answer, :text
      modify :multi_answer, {:array, :text}
    end
  end

  def down do
    alter table(:events) do
      modify :description, :string
      modify :location, :string
      modify :image_url, :string
    end

    alter table(:forms) do
      modify :description, :string
    end

    alter table(:form_questions) do
      modify :description, :string
      modify :options, {:array, :string}
    end

    alter table(:form_question_responses) do
      modify :answer, :string
      modify :multi_answer, {:array, :string}
    end
  end
end

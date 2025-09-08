defmodule Tiki.Repo.Migrations.DynamicTranslations do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :name_sv, :string
      add :description_sv, :text
    end

    alter table(:forms) do
      add :description_sv, :text
    end

    alter table(:form_questions) do
      add :name_sv, :string
      add :description_sv, :text
      add :options_sv, {:array, :string}
    end

    alter table(:ticket_types) do
      add :name_sv, :string
      add :description_sv, :text
    end

    execute("UPDATE events SET name_sv = name, description_sv = description", "")
    execute("UPDATE forms SET description_sv = description;", "")

    execute(
      "UPDATE form_questions SET name_sv = name, description_sv = description, options_sv = options;",
      ""
    )

    execute("UPDATE ticket_types SET name_sv = name, description_sv = description;", "")
  end
end

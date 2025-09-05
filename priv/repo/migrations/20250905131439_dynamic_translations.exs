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
  end
end

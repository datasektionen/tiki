defmodule Tiki.Repo.Migrations.AddFoodPreferences do
  use Ecto.Migration

  def change do
    create table(:foods) do
      add :name, :string

      timestamps()
    end

    alter table(:users) do
      add :food_preference_other, :text
    end

    create table(:food_preferences) do
      add :food_id, references(:foods)
      add :user_id, references(:users)
    end

    create unique_index(:food_preferences, [:food_id, :user_id])
  end
end

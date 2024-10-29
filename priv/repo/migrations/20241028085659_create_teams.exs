defmodule Tiki.Repo.Migrations.CreateTeams do
  use Ecto.Migration

  def change do
    create table(:teams) do
      add :name, :string

      timestamps()
    end

    alter table(:events) do
      add :team_id, references(:teams, on_delete: :delete_all)
    end

    create index(:events, [:team_id])
  end
end

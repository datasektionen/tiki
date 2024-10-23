defmodule Tiki.Repo.Migrations.AddAccountData do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :first_name, :string
      add :last_name, :string

      add :locale, :string
    end

    execute """
    ALTER TABLE users
      ADD COLUMN full_name TEXT
      GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED;
    """
  end

  def down do
    alter table(:users) do
      drop :full_name

      drop :first_name, :string

      drop :last_name, :string
      drop :locale, :string
    end
  end
end

defmodule Tiki.Repo.Migrations.AddAccountData do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :first_name, :string
      add :last_name, :string
      add :kth_id, :string

      modify :hashed_password, :string, null: true

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
      remove :full_name

      modify :hashed_password, :string, null: false

      remove :first_name
      remove :last_name
      remove :kth_id
      remove :locale
    end
  end
end

defmodule Tiki.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto"

    create table(:events, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")
      add :name, :string
      add :description, :text
      add :event_date, :utc_datetime

      timestamps()
    end
  end

  def down do
    drop table(:events)

    execute "DROP EXTENSION IF EXISTS pgcrypto"
  end
end

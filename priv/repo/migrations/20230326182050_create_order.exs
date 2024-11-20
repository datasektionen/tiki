defmodule Tiki.Repo.Migrations.CreateOrder do
  use Ecto.Migration

  def change do
    create table(:orders, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")

      add :user_id, references(:users, on_delete: :nothing)

      timestamps()
    end

    create index(:orders, [:user_id])
  end
end

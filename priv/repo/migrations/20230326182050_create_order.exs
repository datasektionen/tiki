defmodule Tiki.Repo.Migrations.CreateOrder do
  use Ecto.Migration

  def change do
    create table(:orders) do
      add :user_id, references(:users, on_delete: :nothing)

      timestamps()
    end

    create index(:orders, [:user_id])
  end
end

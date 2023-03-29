defmodule Tiki.Repo.Migrations.AddEventToOrder do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add :event_id, references(:events, on_delete: :delete_all)
    end

    create index(:orders, [:event_id])
  end
end

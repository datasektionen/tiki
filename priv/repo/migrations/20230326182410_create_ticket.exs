defmodule Tiki.Repo.Migrations.CreateTicket do
  use Ecto.Migration

  def change do
    create table(:tickets) do
      add :order_id, references(:orders, on_delete: :nothing)
      add :ticket_type_id, references(:ticket_types, on_delete: :nothing)

      timestamps()
    end

    create index(:tickets, [:ticket_type_id])
    create index(:tickets, [:order_id])
  end
end

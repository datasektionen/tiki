defmodule Tiki.Repo.Migrations.CreateTicket do
  use Ecto.Migration

  def change do
    create table(:tickets, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")
      add :order_id, references(:orders, type: :binary_id, on_delete: :nothing)
      add :ticket_type_id, references(:ticket_types, type: :binary_id, on_delete: :nothing)

      timestamps()
    end

    create index(:tickets, [:ticket_type_id])
    create index(:tickets, [:order_id])
  end
end

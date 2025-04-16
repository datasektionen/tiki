defmodule Tiki.Repo.Migrations.AddOrderAuditLog do
  use Ecto.Migration

  def change do
    create table(:order_audit_logs) do
      add :event_type, :string
      add :metadata, :map
      add :order_id, references(:orders, type: :binary_id, on_delete: :nilify_all)

      timestamps(updated_at: false)
    end
  end
end

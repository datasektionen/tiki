defmodule Tiki.Repo.Migrations.CreateTicketBatch do
  use Ecto.Migration

  def change do
    create table(:ticket_batches) do
      add :name, :string
      add :min_size, :integer
      add :max_size, :integer
      add :event_id, references(:events, on_delete: :nothing)
      add :parent_batch_id, references(:ticket_batches, on_delete: :delete_all)

      timestamps()
    end

    create index(:ticket_batches, [:event_id])
  end
end

defmodule Tiki.Repo.Migrations.CreateTicketType do
  use Ecto.Migration

  def change do
    create table(:ticket_types) do
      add :name, :string
      add :description, :text
      add :purchasable, :boolean, default: true, null: false
      add :price, :integer
      add :release_time, :utc_datetime
      add :expire_time, :utc_datetime
      add :ticket_batch_id, references(:ticket_batches, on_delete: :nothing)

      timestamps()
    end

    create index(:ticket_type, [:ticket_batches])
  end
end

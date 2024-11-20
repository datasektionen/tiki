defmodule Tiki.Repo.Migrations.CreateTicketType do
  use Ecto.Migration

  def change do
    create table(:ticket_types, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")
      add :name, :string
      add :description, :text
      add :purchasable, :boolean, default: true, null: false
      add :price, :integer
      add :release_time, :utc_datetime
      add :expire_time, :utc_datetime
      add :ticket_batch_id, references(:ticket_batches, on_delete: :nothing)

      timestamps()
    end

    create index(:ticket_types, [:ticket_batch_id])
  end
end

defmodule Tiki.Repo.Migrations.CreateReleases do
  use Ecto.Migration

  def change do
    create table(:releases, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")

      add :name, :string
      add :name_sv, :string
      add :starts_at, :utc_datetime
      add :ends_at, :utc_datetime

      add :event_id, references(:events, on_delete: :nothing, type: :binary_id)
      add :ticket_batch_id, references(:ticket_batches, on_delete: :nothing)

      timestamps()
    end

    create index(:releases, [:event_id])
    create index(:releases, [:ticket_batch_id])

    create table(:release_signups, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")

      add :position, :integer
      add :status, :string, default: "pending"

      add :signed_up_at, :utc_datetime

      add :user_id, references(:users, on_delete: :nothing)
      add :release_id, references(:releases, on_delete: :nothing, type: :binary_id)

      timestamps()
    end

    create index(:release_signups, [:user_id])
    create index(:release_signups, [:release_id])

    create unique_index(:release_signups, [:release_id, :user_id])
    create unique_index(:release_signups, [:release_id, :position])
  end
end

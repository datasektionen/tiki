defmodule Tiki.Repo.Migrations.UpdateReleases do
  use Ecto.Migration

  def up do
    # Drop existing release data
    drop_if_exists table(:release_signups)
    drop_if_exists table(:releases)

    create table(:releases, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")

      add :name, :string
      add :name_sv, :string
      add :opens_at, :utc_datetime
      add :signup_window_minutes, :integer
      add :purchase_window_minutes, :integer
      add :max_tickets_per_order, :integer

      add :seed, :integer
      add :drawn_at, :utc_datetime

      add :event_id, references(:events, on_delete: :delete_all, type: :binary_id), null: false
      add :ticket_batch_id, references(:ticket_batches, on_delete: :delete_all), null: false

      timestamps(type: :naive_datetime_usec)
    end

    create index(:releases, [:event_id])
    create index(:releases, [:ticket_batch_id])

    create table(:release_signups, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")

      add :status, :string, default: "queued"

      add :decided_at, :utc_datetime
      add :decided_by_id, references(:users, on_delete: :nothing)

      add :user_id, references(:users, on_delete: :nilify_all)
      add :release_id, references(:releases, on_delete: :delete_all, type: :binary_id)

      add :order_id, references(:orders, on_delete: :nothing, type: :binary_id)

      timestamps(type: :naive_datetime_usec)
    end

    create index(:release_signups, [:user_id])
    create index(:release_signups, [:release_id])
    create index(:release_signups, [:order_id])

    create table(:release_signup_items) do
      add :quantity, :integer, null: false

      add :signup_id, references(:release_signups, on_delete: :delete_all, type: :binary_id)
      add :ticket_type_id, references(:ticket_types, on_delete: :delete_all, type: :binary_id)

      timestamps(type: :naive_datetime_usec)
    end

    create index(:release_signup_items, [:signup_id])
    create index(:release_signup_items, [:ticket_type_id])

    create unique_index(:release_signups, [:release_id, :user_id],
             name: :release_signups_id_user_id_index
           )
  end

  def down do
    drop table(:release_signup_items)
    drop table(:release_signups)
    drop table(:releases)

    # recreate old structure

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

    execute(
      """
        ALTER TABLE release_signups
        ADD CONSTRAINT release_signups_release_id_user_id_unique UNIQUE (release_id, user_id) DEFERRABLE INITIALLY DEFERRED;
      """,
      ""
    )

    execute(
      """
        ALTER TABLE release_signups
        ADD CONSTRAINT release_signups_release_id_position_unique UNIQUE (release_id, position) DEFERRABLE INITIALLY DEFERRED;
      """,
      ""
    )
  end
end

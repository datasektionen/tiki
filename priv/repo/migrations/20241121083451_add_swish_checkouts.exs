defmodule Tiki.Repo.Migrations.AddSwishCheckouts do
  use Ecto.Migration

  def change do
    create table(:swish_checkouts) do
      add :swish_id, :string
      add :callback_identifier, :string
      add :token, :string
      add :status, :string

      add :user_id, references(:users, on_delete: :nothing)
      add :order_id, references(:orders, on_delete: :nothing, type: :binary_id)

      timestamps()
    end

    create index(:swish_checkouts, [:user_id])
    create index(:swish_checkouts, [:order_id])
  end
end

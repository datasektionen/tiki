defmodule Tiki.Repo.Migrations.CreateStripeCheckouts do
  use Ecto.Migration

  def change do
    create table(:stripe_checkouts) do
      add :currency, :string
      add :payment_intent_id, :string
      add :payment_method_id, :string
      add :status, :string
      add :user_id, references(:users, on_delete: :nothing)
      add :order_id, references(:orders, type: :binary_id, on_delete: :nothing)

      timestamps()
    end

    create index(:stripe_checkouts, [:user_id])
    create index(:stripe_checkouts, [:order_id])
  end
end

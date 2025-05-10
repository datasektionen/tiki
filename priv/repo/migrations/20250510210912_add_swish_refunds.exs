defmodule Tiki.Repo.Migrations.AddSwishRefunds do
  use Ecto.Migration

  def change do
    create table(:swish_refunds) do
      add :refund_id, :string
      add :callback_identifier, :string
      add :status, :string

      add :swish_checkout_id, references(:swish_checkouts, on_delete: :delete_all)

      timestamps()
    end
  end
end

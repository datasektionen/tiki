defmodule Tiki.Repo.Migrations.AddOrderStatus do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add :status, :string, default: "pending"
    end
  end
end

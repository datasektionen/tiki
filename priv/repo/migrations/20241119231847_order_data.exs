defmodule Tiki.Repo.Migrations.OrderData do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add :price, :integer
    end
  end
end

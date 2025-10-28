defmodule Tiki.Repo.Migrations.AddUniqueConstraintToKthId do
  use Ecto.Migration

  def change do
    create unique_index(:users, [:kth_id])
  end
end

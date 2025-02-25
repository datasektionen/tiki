defmodule Tiki.Repo.Migrations.AddHiddenEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :is_hidden, :boolean, default: false
    end
  end
end

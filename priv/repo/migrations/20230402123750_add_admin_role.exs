defmodule Tiki.Repo.Migrations.AddAdminRole do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :role, :string, default: "user"
    end
  end
end

defmodule Tiki.Repo.Migrations.AddUserYearTag do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :year_tag, :string
    end
  end
end

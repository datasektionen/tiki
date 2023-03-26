defmodule Tiki.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :name, :string
      add :description, :text
      add :event_date, :utc_datetime

      timestamps()
    end
  end
end

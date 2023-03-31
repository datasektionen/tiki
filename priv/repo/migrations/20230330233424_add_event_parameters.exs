defmodule Tiki.Repo.Migrations.AddEventParameters do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :image_url, :string
      add :location, :string
    end
  end
end

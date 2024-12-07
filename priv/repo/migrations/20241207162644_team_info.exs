defmodule Tiki.Repo.Migrations.TeamInfo do
  use Ecto.Migration

  def change do
    alter table(:teams) do
      add :logo_url, :text
      add :description, :text
      add :contact_email, :string
    end
  end
end

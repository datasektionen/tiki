defmodule Tiki.Repo.Migrations.AddTicketPrice do
  use Ecto.Migration

  def change do
    alter table(:tickets) do
      add :price, :integer
    end
  end
end

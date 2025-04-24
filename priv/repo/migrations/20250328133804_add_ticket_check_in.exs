defmodule Tiki.Repo.Migrations.AddTicketCheckIn do
  use Ecto.Migration

  def change do
    alter table(:tickets) do
      add :checked_in_at, :naive_datetime
    end
  end
end

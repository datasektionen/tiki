defmodule Tiki.Repo.Migrations.EventEndDates do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :end_time, :utc_datetime
    end

    rename table(:events), :event_date, to: :start_time
  end
end

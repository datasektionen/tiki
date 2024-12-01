defmodule Tiki.Repo.Migrations.AddDefaultTimeToTickets do
  use Ecto.Migration

  def up do
    alter table(:tickets) do
      modify :inserted_at, :utc_datetime, default: fragment("now() at time zone 'utc'")
      modify :updated_at, :utc_datetime, default: fragment("now() at time zone 'utc'")
    end
  end

  def down do
    alter table(:tickets) do
      modify :inserted_at, :utc_datetime
      modify :updated_at, :utc_datetime
    end
  end
end

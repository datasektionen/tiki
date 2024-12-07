defmodule Tiki.Repo.Migrations.MorePreciseTimestamps do
  use Ecto.Migration

  def up do
    alter table(:tickets) do
      modify :inserted_at, :naive_datetime_usec, default: fragment("now()")
      modify :updated_at, :naive_datetime_usec, default: fragment("now()")
    end
  end

  def down do
    alter table(:tickets) do
      modify :inserted_at, :utc_datetime, default: fragment("now() at time zone 'utc'")
      modify :updated_at, :utc_datetime, default: fragment("now() at time zone 'utc'")
    end
  end
end

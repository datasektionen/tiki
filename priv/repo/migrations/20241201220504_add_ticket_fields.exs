defmodule Tiki.Repo.Migrations.AddTicketFields do
  use Ecto.Migration

  def change do
    alter table(:ticket_types) do
      add :start_time, :utc_datetime
      add :end_time, :utc_datetime
    end

    alter table(:events) do
      add :default_form_id, references(:forms)
    end
  end
end

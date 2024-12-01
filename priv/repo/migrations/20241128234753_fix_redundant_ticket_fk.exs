defmodule Tiki.Repo.Migrations.FixRedundantTicketFk do
  use Ecto.Migration

  def change do
    drop index(:tickets, [:response_id])

    alter table(:tickets) do
      remove :response_id
    end
  end
end

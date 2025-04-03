defmodule Tiki.Repo.Migrations.TicketLimits do
  use Ecto.Migration

  def change do
    alter table(:ticket_types) do
      add :purchase_limit, :integer
    end

    alter table(:events) do
      add :max_order_size, :integer
    end
  end
end

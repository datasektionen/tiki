defmodule Tiki.Repo.Migrations.RemoveMinSizeFromTicketBatches do
  use Ecto.Migration

  def change do
    alter table(:ticket_batches) do
      remove :min_size, :integer
    end
  end
end

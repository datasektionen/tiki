defmodule Tiki.Repo.Migrations.PromoCodes do
  use Ecto.Migration

  def change do
    alter table(:ticket_types) do
      add :promo_code, :string
    end
  end
end

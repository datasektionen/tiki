defmodule Tiki.Repo.Migrations.FixAccountFullName do
  use Ecto.Migration

  def up do
    execute """
    ALTER TABLE users DROP COLUMN full_name;
    """

    execute """
    ALTER TABLE users
      ADD COLUMN full_name TEXT
      GENERATED ALWAYS AS (
        CASE
          WHEN first_name IS NULL AND last_name IS NULL THEN NULL
          WHEN first_name IS NULL THEN last_name
          WHEN last_name IS NULL THEN first_name
          ELSE first_name || ' ' || last_name
        END
      ) STORED;
    """
  end

  def down do
    execute """
    ALTER TABLE users DROP COLUMN full_name;
    """

    execute """
    ALTER TABLE users
      ADD COLUMN full_name TEXT
      GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED;
    """
  end
end

defmodule Tiki.ReleasesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Tiki.Releases` context.
  """

  @doc """
  Generate a release.
  """
  def release_fixture(attrs \\ %{}) do
    {:ok, release} =
      attrs
      |> Enum.into(%{
        ends_at: ~U[2025-09-10 13:05:00Z],
        name: "some name",
        name_sv: "some name_sv",
        starts_at: ~U[2025-09-10 13:05:00Z]
      })
      |> Tiki.Releases.create_release()

    release
  end
end

defmodule Tiki.ReleasesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Tiki.Releases` context.
  """

  @doc """
  Generate a release.
  """
  def release_fixture(attrs \\ %{}) do
    ticket_batch =
      Tiki.TicketsFixtures.ticket_batch_fixture()

    {:ok, release} =
      attrs
      |> Enum.into(%{
        ends_at: ~U[2025-09-10 13:05:00Z] |> DateTime.shift_zone!("Europe/Stockholm"),
        name: "some name",
        name_sv: "some name_sv",
        starts_at: ~U[2025-09-10 13:05:00Z] |> DateTime.shift_zone!("Europe/Stockholm"),
        ticket_batch_id: ticket_batch.id,
        event_id: ticket_batch.event_id
      })
      |> Tiki.Releases.create_release()

    release
  end
end

defmodule Tiki.EventsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Tiki.Events` context.
  """

  @doc """
  Generate a event.
  """
  def event_fixture(attrs \\ %{}) do
    {:ok, event} =
      attrs
      |> Enum.into(%{
        description: "some description",
        event_date: ~U[2023-03-25 16:55:00Z],
        name: "some name"
      })
      |> Tiki.Events.create_event()

    event
  end
end
